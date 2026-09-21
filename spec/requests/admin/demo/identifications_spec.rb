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
      post admin_demo_identification_path, params: { france_connect: 'fake' }

      expect(response.headers['Location']).to start_with("#{FranceConnectStubs::AUTHORIZATION_ENDPOINT}?")
      expect(session[:france_connect].symbolize_keys)
        .to include(name: 'fake').and(have_key(:state)).and(have_key(:nonce))
    end

    it 'departs afresh each time, rather than replaying a state already spent' do
      post admin_demo_identification_path, params: { france_connect: 'fake' }
      first = session[:france_connect].symbolize_keys.fetch(:state)

      post admin_demo_identification_path, params: { france_connect: 'fake' }

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
        post admin_demo_identification_path, params: { france_connect: 'real' }

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
        post admin_demo_identification_path, params: { france_connect: 'fake' }

        expect(response.headers['Location']).to start_with("#{FranceConnectStubs::AUTHORIZATION_ENDPOINT}?")
        expect(a_request(:get, FranceConnectStubs::REAL_DISCOVERY_URL)).not_to have_been_made
      end

      it 'remembers which FranceConnect+ the departure was made on' do
        post admin_demo_identification_path, params: { france_connect: 'real' }

        expect(session[:france_connect].symbolize_keys.fetch(:name)).to eq('real')
      end

      # CA8: a portal that cannot be reached costs its own identification and
      # nothing more — the home page comes back with its two buttons, and the
      # other one is played straight away.
      it 'brings the operator back to the two buttons when one portal cannot be reached, and plays the other' do
        stub_request(:get, FranceConnectStubs::REAL_DISCOVERY_URL).to_timeout

        post admin_demo_identification_path, params: { france_connect: 'real' }

        expect(response).to redirect_to(admin_demo_root_path)
        follow_redirect!
        expect(response.parsed_body.css('.fr-alert').text)
          .to include("L'identification par FranceConnect+ n'a pas abouti")
        expect(response.parsed_body.css('main button.fr-btn').map { |button| button.text.strip })
          .to eq(['🇪🇺 Choose a country to sign-in', '🇪🇺 Choose a country to sign-in (mocked)'])

        post admin_demo_identification_path, params: { france_connect: 'fake' }
        expect(response.headers['Location']).to start_with("#{FranceConnectStubs::AUTHORIZATION_ENDPOINT}?")
      end
    end

    # CA9: what the page receives from a browser does not choose where the
    # `client_secret` and the user are sent. Refused before any discovery —
    # there is nothing to ask, and asking would be choosing for the operator.
    it 'sends a submission naming a FranceConnect+ this deployment does not declare back to the procedure' do
      post admin_demo_identification_path, params: { france_connect: 'real' }

      expect(response).to redirect_to(admin_demo_root_path)
      expect(a_request(:get, FranceConnectStubs::DISCOVERY_URL)).not_to have_been_made
      expect(session[:france_connect]).to be_nil
    end

    it 'sends a submission naming no FranceConnect+ at all back the same way' do
      post admin_demo_identification_path

      expect(response).to redirect_to(admin_demo_root_path)
      expect(a_request(:get, FranceConnectStubs::DISCOVERY_URL)).not_to have_been_made
    end

    # Nothing is held, and the operator is told: `docs/espace_administration.md`
    # names the console's audience, and this is the one page of the demonstration
    # they can act on.
    it 'sends the operator back to the procedure, saying why, when the portal cannot be reached' do
      stub_code_list
      stub_demonstration_requirements
      stub_request(:get, FranceConnectStubs::DISCOVERY_URL).to_timeout

      post admin_demo_identification_path, params: { france_connect: 'fake' }

      expect(response).to redirect_to(admin_demo_root_path)
      follow_redirect!
      expect(response.parsed_body.css('.fr-alert').text)
        .to include("L'identification par FranceConnect+ n'a pas abouti", 'découverte')
    end
  end

  describe 'POST /admin/demo/identification without a session' do
    it 'sends the visitor to the login page' do
      post admin_demo_identification_path, params: { france_connect: 'fake' }

      expect(response).to redirect_to(new_admin_session_path)
    end
  end

  # A GET would be prefetched and replayed, overwriting the state and the nonce
  # of a flow under way.
  describe 'GET /admin/demo/identification' do
    it 'is not a route at all' do
      get '/admin/demo/identification'

      expect(response).to have_http_status(:not_found)
    end
  end
end
