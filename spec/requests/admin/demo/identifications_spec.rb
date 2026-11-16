require 'rails_helper'

RSpec.describe 'Admin::Demo::Identifications' do
  describe 'POST /admin/demo/identification' do
    before do
      sign_in
      stub_france_connect
    end

    # RG8: the browser is handed straight to the European flow, and the two
    # values the return will be checked against are written where only this
    # session can read them.
    it 'hands the browser to FranceConnect+ and remembers what ties the return to this departure' do
      post admin_demo_identification_path(version: 'v2.0', procedure: 'T1'), params: { france_connect: 'fake' }

      expect(response.headers['Location']).to start_with("#{FranceConnectStubs::AUTHORIZATION_ENDPOINT}?")
      expect(session[:france_connect].symbolize_keys)
        .to include(name: 'fake').and(have_key(:state)).and(have_key(:nonce))
    end

    # The return addresses name no line and no procedure, so the departure
    # keeps those of the page it left from.
    it 'remembers the line and the procedure of the sign-in page the departure left from' do
      post admin_demo_identification_path(version: 'v1.2', procedure: '00'), params: { france_connect: 'fake' }

      expect(session[:france_connect].symbolize_keys).to include(version: 'v1.2', procedure: '00')
    end

    it 'departs afresh each time, rather than replaying a state already spent' do
      post admin_demo_identification_path(version: 'v2.0', procedure: 'T1'), params: { france_connect: 'fake' }
      first = session[:france_connect].symbolize_keys.fetch(:state)

      post admin_demo_identification_path(version: 'v2.0', procedure: 'T1'), params: { france_connect: 'fake' }

      expect(session[:france_connect].symbolize_keys.fetch(:state)).not_to eq(first)
    end

    # CA4: the card names its FranceConnect+, and the departure is built on
    # **its** discovery — the address is the one that document publishes, and
    # not one address of two that happened to be configured.
    context 'when the deployment declares both' do
      before do
        stub_code_list
        stub_demonstration_requirements
        stub_real_france_connect
      end

      it 'departs on the /authorize the real one publishes, and asks the fake nothing' do
        post admin_demo_identification_path(version: 'v2.0', procedure: 'T1'), params: { france_connect: 'real' }

        parameters = URI.decode_www_form(URI.parse(response.headers['Location']).query).to_h

        expect(response.headers['Location']).to start_with("#{FranceConnectStubs::REAL_AUTHORIZATION_ENDPOINT}?")
        expect(parameters).to include('idp_hint' => 'eidas-bridge', 'acr_values' => 'eidas2',
          'client_id' => FranceConnectStubs::REAL_CLIENT_ID,
          'redirect_uri' => "#{FranceConnectStubs::PROCEDURE_URL}/demo/franceconnect/retour_connexion")
        expect(a_request(:get, FranceConnectStubs::DISCOVERY_URL)).not_to have_been_made
      end

      # CA6, the same the other way round: one card cannot reach the other's
      # portal, the client rebuilding every address on the issuer it was given.
      it 'departs on the /authorize the fake publishes, and asks the real one nothing' do
        post admin_demo_identification_path(version: 'v2.0', procedure: 'T1'), params: { france_connect: 'fake' }

        expect(response.headers['Location']).to start_with("#{FranceConnectStubs::AUTHORIZATION_ENDPOINT}?")
        expect(a_request(:get, FranceConnectStubs::REAL_DISCOVERY_URL)).not_to have_been_made
      end

      it 'remembers which FranceConnect+ the departure was made on' do
        post admin_demo_identification_path(version: 'v2.0', procedure: 'T1'), params: { france_connect: 'real' }

        expect(session[:france_connect].symbolize_keys.fetch(:name)).to eq('real')
      end

      # CA8: a portal that cannot be reached costs its own identification and
      # nothing more — the home page comes back with its two buttons, and the
      # other one is played straight away.
      it 'brings the operator back to the two buttons when one portal cannot be reached, and plays the other' do
        stub_request(:get, FranceConnectStubs::REAL_DISCOVERY_URL).to_timeout

        post admin_demo_identification_path(version: 'v2.0', procedure: 'T1'), params: { france_connect: 'real' }

        expect(response).to redirect_to(admin_demo_home_path(version: 'v2.0', procedure: 'T1'))
        follow_redirect!
        expect(response.parsed_body.css('.fr-alert').text)
          .to include("L'identification par FranceConnect+ n'a pas abouti")
        expect(response.parsed_body.css('main button.fr-btn').map { |button| button.text.strip })
          .to eq(['🇪🇺 Choisir un pays pour se connecter', '🇪🇺 Choisir un pays pour se connecter (simulé)'])

        post admin_demo_identification_path(version: 'v2.0', procedure: 'T1'), params: { france_connect: 'fake' }
        expect(response.headers['Location']).to start_with("#{FranceConnectStubs::AUTHORIZATION_ENDPOINT}?")
      end
    end

    # CA9: what the page receives from a browser does not choose where the
    # `client_secret` and the user are sent. Refused before any discovery —
    # there is nothing to ask, and asking would be choosing for the operator.
    it 'sends a submission naming a FranceConnect+ this deployment does not declare back to the procedure' do
      post admin_demo_identification_path(version: 'v2.0', procedure: 'T1'), params: { france_connect: 'real' }

      expect(response).to redirect_to(admin_demo_home_path(version: 'v2.0', procedure: 'T1'))
      expect(a_request(:get, FranceConnectStubs::DISCOVERY_URL)).not_to have_been_made
      expect(session[:france_connect]).to be_nil
    end

    it 'sends a submission naming no FranceConnect+ at all back the same way' do
      post admin_demo_identification_path(version: 'v1.2', procedure: '00')

      expect(response).to redirect_to(admin_demo_home_path(version: 'v1.2', procedure: '00'))
      expect(a_request(:get, FranceConnectStubs::DISCOVERY_URL)).not_to have_been_made
    end

    # Nothing is held, and the operator is told: `docs/espace_administration.md`
    # names the console's audience, and this is the one page of the demonstration
    # they can act on.
    it 'sends the operator back to the procedure, saying why, when the portal cannot be reached' do
      stub_code_list
      stub_demonstration_requirements
      stub_request(:get, FranceConnectStubs::DISCOVERY_URL).to_timeout

      post admin_demo_identification_path(version: 'v2.0', procedure: 'T1'), params: { france_connect: 'fake' }

      expect(response).to redirect_to(admin_demo_home_path(version: 'v2.0', procedure: 'T1'))
      follow_redirect!
      expect(response.parsed_body.css('.fr-alert').text)
        .to include("L'identification par FranceConnect+ n'a pas abouti", 'découverte')
    end
  end

  describe 'POST /admin/demo/identification without a session' do
    it 'sends the visitor to the login page' do
      post admin_demo_identification_path(version: 'v2.0', procedure: 'T1'), params: { france_connect: 'fake' }

      expect(response).to redirect_to(new_admin_session_path)
    end
  end

  # The button of the identity card: the FranceConnect+ session ends, the
  # console's does not.
  describe 'DELETE /admin/demo/identification' do
    def location_parameters = URI.decode_www_form(URI.parse(response.headers['Location']).query).to_h

    def sign_out_of_france_connect = delete admin_demo_identification_path(version: 'v2.0', procedure: 'T1')

    def journey = Demo::Journey.from_session(session[:demo_journey])

    # The home the agent is sent back to, with its alert, read as it renders.
    def home_text
      stub_code_list
      stub_demonstration_requirements
      follow_redirect!
      response.parsed_body.css('main').text
    end

    context 'when the fake FranceConnect+ attested the identity' do
      before do
        sign_in
        declare_france_connect(real_france_connect)
        identify_demo_user
      end

      # CA2
      it 'sends the browser to its end of session, with the hint, a state and the declared address' do
        sign_out_of_france_connect

        expect(response.headers['Location']).to start_with(FranceConnectStubs::END_SESSION_ENDPOINT)
        parameters = location_parameters
        expect(parameters.fetch('id_token_hint').split('.').size).to eq(3)
        expect(parameters.fetch('state')).to eq(session[:france_connect_logout])
        expect(parameters.fetch('post_logout_redirect_uri'))
          .to eq("#{FranceConnectStubs::PROCEDURE_URL}/demo/franceconnect/retour_deconnexion")
      end

      # CA3
      it 'forgets the identity, the journey and its cards' do
        Demo::Card.create!(journey_id: journey.id, requirement_uuid: SecureRandom.uuid, country_code: 'FI')

        sign_out_of_france_connect

        expect(demo_identity_cookies).to be_empty
        expect(session[:demo_journey]).to be_nil
        expect(Demo::Card.count).to eq(0)
        get admin_demo_documents_path(version: 'v2.0', procedure: 'T1')
        expect(response).to redirect_to(admin_demo_root_path)
      end

      # CA4
      it 'leaves the console open' do
        sign_out_of_france_connect

        get admin_demo_root_path
        expect(response).to have_http_status(:ok)
      end

      # CA5, as the screen review of OOTS-296 settled it: back to the home of
      # the procedure the agent left, rather than to the page of the return.
      it 'sends the agent back to the home of the procedure on the return FranceConnect+ makes with its state' do
        sign_out_of_france_connect

        get '/demo/franceconnect/retour_deconnexion', params: { state: location_parameters.fetch('state') }

        expect(response).to redirect_to(admin_demo_home_path(version: 'v2.0', procedure: 'T1'))
        expect(home_text).to include('Votre session FranceConnect+ est close')
      end

      it 'renders the page of the return, attesting nothing, when the state is not the one drawn' do
        sign_out_of_france_connect

        get '/demo/franceconnect/retour_deconnexion', params: { state: 'un-autre' }

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body.css('main').text).not_to include('session FranceConnect+ est close')
        expect(session[:france_connect_logout_home]).to be_nil
      end

      # CA6: the same identity, a new conversation.
      it 'opens the next journey under a new conversation, even for the same identity' do
        left = journey.conversation_id
        sign_out_of_france_connect

        identify_demo_user

        expect(journey.conversation_id).not_to eq(left)
      end

      # CA7
      it 'forgets the identity anyway and says so when the portal cannot be reached' do
        stub_request(:get, FranceConnectStubs::DISCOVERY_URL).to_timeout
        allow(Rails.logger).to receive(:warn)

        sign_out_of_france_connect

        expect(response).to redirect_to(admin_demo_home_path(version: 'v2.0', procedure: 'T1'))
        expect(Rails.logger).to have_received(:warn).with(/Fin de session FranceConnect\+ impossible/)
        expect(demo_identity_cookies).to be_empty
        expect(home_text).to include("La session FranceConnect+ n'a pas pu être close")
      end

      # CA8
      it 'forgets the identity anyway and says so when that FranceConnect+ is no longer declared' do
        undeclare_france_connect('fake')
        allow(Rails.logger).to receive(:warn)

        sign_out_of_france_connect

        expect(response).to redirect_to(admin_demo_home_path(version: 'v2.0', procedure: 'T1'))
        expect(flash[:alert]).to eq(:'controllers.admin.demo.identifications.not_closed')
        expect(Rails.logger).to have_received(:warn).with(/Session FranceConnect\+ non close.*fake/)
        expect(demo_identity_cookies).to be_empty
      end
    end

    # The session ended is the one that attested, and no other.
    it 'ends the session of the real FranceConnect+ when the real one attested' do
      sign_in
      identify_demo_user(instance: real_france_connect)

      sign_out_of_france_connect

      expect(response.headers['Location']).to start_with(FranceConnectStubs::REAL_END_SESSION_ENDPOINT)
      expect(a_request(:get, FranceConnectStubs::DISCOVERY_URL)).not_to have_been_made
    end

    it 'goes back to the home of the procedure without an alert when no identity is held' do
      sign_in

      sign_out_of_france_connect

      expect(response).to redirect_to(admin_demo_home_path(version: 'v2.0', procedure: 'T1'))
      expect(flash[:alert]).to be_nil
    end

    it 'sends a visitor without a session to the login page' do
      sign_out_of_france_connect

      expect(response).to redirect_to(new_admin_session_path)
    end
  end

  # A GET would be prefetched and replayed, overwriting the state and the nonce
  # of a flow under way.
  describe 'GET /admin/demo/v2.0/T1/identification' do
    it 'is not a route at all' do
      get '/admin/demo/v2.0/T1/identification'

      expect(response).to have_http_status(:not_found)
    end
  end
end
