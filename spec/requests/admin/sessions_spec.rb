require 'rails_helper'

RSpec.describe 'Admin::Sessions' do
  def location_parameters = URI.decode_www_form(URI.parse(response.headers['Location']).query).to_h

  def page_text = response.parsed_body.text.squish

  describe 'GET /admin/session/new' do
    before { stub_pro_connect }

    # CA1: the button, its link, and no field.
    it 'offers the ProConnect button, and nothing to type in' do
      get new_admin_session_path

      expect(response).to have_http_status(:ok)
      page = response.parsed_body
      expect(page.css('button.fr-proconnect').text).to include('ProConnect')
      expect(page.css('a[href="https://www.proconnect.gouv.fr/"]').text).to eq("Qu'est-ce que ProConnect ?")
      expect(page.css('input[type="password"], input[type="email"]')).to be_empty
    end

    # CA12: no ProConnect declared, no button — and a sentence saying why.
    it 'says no ProConnect is declared, and offers no ProConnect button, when none is' do
      undeclare_pro_connect

      get new_admin_session_path

      expect(response.parsed_body.css('button.fr-proconnect')).to be_empty
      expect(page_text).to include("Aucun ProConnect n'est déclaré : l'espace d'administration ne peut pas s'ouvrir.")
    end

    # The header's navigation belongs to the space, and none of it can be
    # reached from here.
    it 'carries no navigation' do
      get new_admin_session_path

      expect(response.parsed_body.css('.fr-nav')).to be_empty
    end
  end

  # CA2: the departure, as the button makes it.
  describe 'POST /admin/session' do
    before { stub_pro_connect }

    it 'sends the browser to the authorization endpoint with the six parameters, and no seventh' do
      post admin_session_path

      expect(response.headers['Location']).to start_with(ProConnectStubs::AUTHORIZATION_ENDPOINT)
      parameters = location_parameters
      expect(parameters.keys).to match_array(%w[response_type client_id redirect_uri scope state nonce])
      expect(parameters).to include('response_type' => 'code', 'client_id' => ProConnectStubs::CLIENT_ID,
        'scope' => 'openid email',
        'redirect_uri' => "#{ProConnectStubs::CONSOLE_URL}/admin/proconnect/retour_connexion")
    end

    it 'keeps a state and a nonce of at least thirty-two characters in the session' do
      post admin_session_path

      expect(session[:pro_connect]).to eq(location_parameters.slice('state', 'nonce'))
      expect(session[:pro_connect].values).to all(have_attributes(size: be >= 32))
    end

    it 'says the sign-in failed when ProConnect cannot be discovered' do
      stub_request(:get, "#{ProConnectStubs::ISSUER}#{ProConnectClient::DISCOVERY_PATH}").to_timeout

      post admin_session_path
      follow_redirect!

      expect(page_text).to include("La connexion par ProConnect n'a pas abouti. Réessayez.")
    end

    it 'departs nowhere when no ProConnect is declared' do
      undeclare_pro_connect

      post admin_session_path

      expect(response).to redirect_to(new_admin_session_path)
    end
  end

  describe 'DELETE /admin/session' do
    # CA7: the end of the ProConnect session, then the login page saying so.
    it 'ends the ProConnect session, with the hint, a state and the declared address' do
      sign_in

      delete admin_session_path

      expect(response.headers['Location']).to start_with(ProConnectStubs::END_SESSION_ENDPOINT)
      parameters = location_parameters
      expect(parameters.fetch('post_logout_redirect_uri'))
        .to eq("#{ProConnectStubs::CONSOLE_URL}/admin/proconnect/retour_deconnexion")
      expect(parameters.fetch('state').size).to be >= 32
      expect(parameters.fetch('id_token_hint').split('.').size).to eq(3)
    end

    it 'says so on the login page once ProConnect brings the agent back, and the space is closed' do
      sign_in
      delete admin_session_path

      get admin_pro_connect_retour_deconnexion_path, params: { state: location_parameters.fetch('state') }
      follow_redirect!
      expect(page_text).to include('Vous êtes déconnecté.')

      get admin_journal_root_path
      expect(response).to redirect_to(new_admin_session_path)
    end

    it 'forgets the ID Token it handed to ProConnect' do
      sign_in

      delete admin_session_path

      expect(cookies[:pro_connect_id_token]).to be_blank
    end

    it 'closes the space at once, before ProConnect brings the agent back' do
      sign_in
      delete admin_session_path

      get admin_root_path

      expect(response).to redirect_to(new_admin_session_path)
    end

    # The agent is signed out here whatever ProConnect does: it closes its own
    # session after twelve hours.
    it 'signs the agent out plainly when ProConnect cannot be reached' do
      sign_in
      stub_request(:get, "#{ProConnectStubs::ISSUER}#{ProConnectClient::DISCOVERY_PATH}").to_timeout

      delete admin_session_path
      expect(response).to redirect_to(new_admin_session_path)
      follow_redirect!
      expect(page_text).to include('Vous êtes déconnecté.')
    end

    it 'refuses a return whose state is not the one the sign-out drew' do
      sign_in
      delete admin_session_path

      get admin_pro_connect_retour_deconnexion_path, params: { state: 'un-autre-state' * 3 }
      follow_redirect!

      expect(page_text).to include("La connexion par ProConnect n'a pas abouti. Réessayez.")
    end

    # CA8: ProConnect first, then the FranceConnect+ session that attested the
    # demonstration identity, which ends on the procedure's own page.
    context 'when the demonstration holds an identity' do
      before do
        sign_in
        identify_demo_user
      end

      def through_pro_connect
        delete admin_session_path
        get admin_pro_connect_retour_deconnexion_path, params: { state: location_parameters.fetch('state') }
      end

      it 'goes through ProConnect, then ends the FranceConnect+ session with the hint and the declared address' do
        through_pro_connect

        expect(response.headers['Location']).to start_with(FranceConnectStubs::END_SESSION_ENDPOINT)
        parameters = location_parameters
        expect(parameters.fetch('post_logout_redirect_uri'))
          .to eq("#{FranceConnectStubs::PROCEDURE_URL}/demo/franceconnect/retour_deconnexion")
        expect(parameters.fetch('id_token_hint').split('.').size).to eq(3)
      end

      it 'holds neither identity nor agent afterwards' do
        through_pro_connect

        expect(session[:demo_identity]).to be_nil
        get admin_root_path
        expect(response).to redirect_to(new_admin_session_path)
      end

      # The return is the only thing that says the sign-out was this browser's.
      it 'recognises the return FranceConnect+ makes with its state' do
        through_pro_connect

        get '/demo/franceconnect/retour_deconnexion', params: { state: location_parameters.fetch('state') }

        expect(response.parsed_body.css('main').text).to include('session FranceConnect+ est close')
      end

      # A deployment that no longer declares it has no session of its own to
      # end: the log is the only place that says so.
      it 'ends the ProConnect session alone when that FranceConnect+ is no longer declared, and says so' do
        undeclare_france_connect('fake')
        allow(Rails.logger).to receive(:warn)

        through_pro_connect

        expect(response).to redirect_to(new_admin_session_path)
        expect(Rails.logger).to have_received(:warn).with(/Session FranceConnect\+ non close.*fake/)
      end

      it 'ends the ProConnect session alone when the FranceConnect+ portal cannot be reached' do
        stub_request(:get, FranceConnectStubs::DISCOVERY_URL).to_timeout

        through_pro_connect

        expect(response).to redirect_to(new_admin_session_path)
      end
    end

    # The session ended is the one that attested, and no other.
    context 'when the real FranceConnect+ attested the identity' do
      before do
        sign_in
        identify_demo_user(instance: real_france_connect)
      end

      it 'ends its session, on the address its own discovery publishes, and never the other' do
        delete admin_session_path
        get admin_pro_connect_retour_deconnexion_path, params: { state: location_parameters.fetch('state') }

        expect(response.headers['Location']).to start_with(FranceConnectStubs::REAL_END_SESSION_ENDPOINT)
        expect(a_request(:get, FranceConnectStubs::DISCOVERY_URL)).not_to have_been_made
      end
    end
  end

  # Admitted again at every request, rather than once at the sign-in.
  describe 'a session whose agent is no longer admitted' do
    it 'no longer opens the space once the domain is taken out of the list' do
      sign_in
      allow(Settings).to receive(:proconnect_agent_domains).and_return(%w[autre.gouv.fr])

      get admin_root_path

      expect(response).to redirect_to(new_admin_session_path)
    end
  end

  # These cases return from ProConnect themselves rather than calling
  # `sign_in`, whose assertion on the root is precisely what they contradict.
  describe 'the page the guard turned away' do
    it 'is where a successful sign-in lands' do
      exchange = create(:exchange, :failed)
      Administrator.appoint(ProConnectStubs::AGENT_EMAIL)

      get admin_journal_exchange_path(exchange.exchange_id)
      expect(response).to redirect_to(new_admin_session_path)

      return_from_pro_connect

      expect(response).to redirect_to(admin_journal_exchange_path(exchange.exchange_id))
      follow_redirect!
      expect(response).to have_http_status(:ok)
    end

    it 'keeps the query string of the page it retains' do
      get admin_journal_root_path(parametre: 'https://exemple.invalid')

      return_from_pro_connect

      expect(response).to redirect_to(admin_journal_root_path(parametre: 'https://exemple.invalid'))
    end

    it 'is the last one turned away when several were' do
      get admin_journal_root_path
      get admin_common_services_root_path

      return_from_pro_connect

      expect(response).to redirect_to(admin_common_services_root_path)
    end

    # Replaying the address of an action as a GET would reach a route that does
    # not exist. `DELETE /admin/session` is the one this application answers;
    # GoodJob's retry and discard buttons are the PUT that motivate the rule.
    it 'is not retained when the request the guard refused was not a GET' do
      delete admin_session_path
      expect(response).to redirect_to(new_admin_session_path)

      return_from_pro_connect

      expect(response).to redirect_to(admin_root_path)
    end

    # A failed return redirects to the login page, which the guard does not
    # run on: the destination outlives it, and serves the attempt that works.
    it 'survives a failed return and serves the attempt that succeeds' do
      get admin_journal_root_path

      return_from_pro_connect(state: 'un-state-qui-ne-correspond-a-rien')
      expect(response).to redirect_to(new_admin_session_path)

      return_from_pro_connect

      expect(response).to redirect_to(admin_journal_root_path)
    end

    # The `reset_session` of the sign-in is what forgets it.
    it 'serves once, and a second sign-in lands on the root again' do
      get admin_journal_root_path
      return_from_pro_connect
      expect(response).to redirect_to(admin_journal_root_path)

      delete admin_session_path
      return_from_pro_connect

      expect(response).to redirect_to(admin_root_path)
    end
  end

  # The key travels as a symbol through the flash and is resolved two steps
  # later, by `layouts/_messages`: neither end is a lookup `i18n-tasks` can see.
  it 'says every flash key the space can redirect with' do
    carried = Dir['app/controllers/**/*.rb']
      .flat_map { |path| File.read(path).scan(/:'(admin\.sessions\.[a-z_]+)'/) }
      .flatten.uniq

    expect_said(carried)
  end
end
