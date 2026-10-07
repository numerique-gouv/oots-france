require 'rails_helper'

RSpec.describe 'Admin::ProConnect' do
  def location_parameters = URI.decode_www_form(URI.parse(response.headers['Location']).query).to_h

  def failed_page
    follow_redirect!

    response.parsed_body.text.squish
  end

  describe 'GET /admin/proconnect/retour_connexion' do
    # CA3: the space opens, in a session whose identifier changed.
    it 'opens the space to an agent of an admitted domain, in a renewed session' do
      get new_admin_session_path
      before = session.id

      return_from_pro_connect

      expect(response).to redirect_to(admin_root_path)
      expect(session.id).not_to eq(before)
      expect(session[:agent_email]).to eq(ProConnectStubs::AGENT_EMAIL)
      expect(session[:pro_connect_id_token].split('.').size).to eq(3)
      follow_redirect!
      expect(response).to have_http_status(:ok)
    end

    it 'presents the code with the credentials in the body' do
      return_from_pro_connect

      expect(a_request(:post, ProConnectStubs::TOKEN_ENDPOINT).with(body: hash_including(
        'grant_type' => 'authorization_code', 'code' => 'un-code',
        'client_id' => ProConnectStubs::CLIENT_ID, 'client_secret' => ProConnectStubs::CLIENT_SECRET,
      ))).to have_been_made
    end

    # CA5: the case of the address does not matter.
    it 'admits an address whose domain differs only by its case' do
      return_from_pro_connect(email: 'Agent@NUMERIQUE.gouv.fr')

      expect(response).to redirect_to(admin_root_path)
    end

    # CA4: nothing opens, ProConnect's session is ended, and the login page
    # names the address.
    context 'when the agent is outside the admitted domains' do
      before { return_from_pro_connect(email: 'agent@exemple.fr') }

      it 'ends the ProConnect session, with the hint and a state' do
        expect(response.headers['Location']).to start_with(ProConnectStubs::END_SESSION_ENDPOINT)
        expect(location_parameters.fetch('id_token_hint').split('.').size).to eq(3)
      end

      it 'names the address on the login page once ProConnect brings the agent back' do
        get admin_pro_connect_retour_deconnexion_path, params: { state: location_parameters.fetch('state') }

        expect(response).to redirect_to(new_admin_session_path)
        expect(failed_page).to include("L'espace d'administration est réservé aux adresses en @numerique.gouv.fr : " \
                                       'vous vous êtes identifié avec « agent@exemple.fr ».')
        expect(response.body).not_to include('Vous êtes déconnecté.')
      end

      it 'says it once, and leaves the space closed' do
        get admin_pro_connect_retour_deconnexion_path, params: { state: location_parameters.fetch('state') }
        get new_admin_session_path
        get new_admin_session_path

        expect(response.body).not_to include('agent@exemple.fr')
        get admin_root_path
        expect(response).to redirect_to(new_admin_session_path)
      end
    end

    it 'refuses a subdomain the list does not name' do
      return_from_pro_connect(email: 'agent@sous.numerique.gouv.fr')

      expect(response.headers['Location']).to start_with(ProConnectStubs::END_SESSION_ENDPOINT)
    end

    # CA6: every return that does not verify opens nothing, says one sentence,
    # and logs the reason.
    context 'when the return does not verify' do
      before { allow(Rails.logger).to receive(:warn) }

      def expect_refused(reason)
        expect(failed_page).to include("La connexion par ProConnect n'a pas abouti. Réessayez.")
        expect(Rails.logger).to have_received(:warn).with(reason)
        expect(session[:agent_email]).to be_nil
      end

      it 'refuses a state that is not the departure one' do
        return_from_pro_connect(state: 'un-autre-state-que-celui-du-depart')

        expect_refused(/state du retour de ProConnect/)
      end

      it 'refuses a nonce that is not the departure one' do
        return_from_pro_connect(nonce: 'un-autre-nonce')

        expect_refused(/nonce/)
      end

      it 'refuses an ID Token signed with another key' do
        stub_pro_connect
        departure = depart_for_pro_connect
        stub_pro_connect_tokens(signed_by_pro_connect(pro_connect_id_token_claims(nonce: departure.fetch('nonce')),
          key: OpenSSL::PKey::RSA.generate(2048)))

        get admin_pro_connect_retour_connexion_path, params: { code: 'un-code', state: departure.fetch('state') }

        expect_refused(/Signature ProConnect invalide/)
      end

      # The `client_secret` is shared with ProConnect: a token signed with it
      # proves only that someone holds it.
      it 'refuses an ID Token signed in HS256 with the client secret' do
        stub_pro_connect
        departure = depart_for_pro_connect
        stub_pro_connect_tokens(signed_by_pro_connect(pro_connect_id_token_claims(nonce: departure.fetch('nonce')),
          key: ProConnectStubs::CLIENT_SECRET, algorithm: 'HS256'))

        get admin_pro_connect_retour_connexion_path, params: { code: 'un-code', state: departure.fetch('state') }

        expect_refused(/Signature ProConnect invalide/)
      end

      it 'refuses a return carrying an error in place of a code' do
        stub_pro_connect
        departure = depart_for_pro_connect

        get admin_pro_connect_retour_connexion_path,
          params: { error: 'access_denied', error_description: 'refus', state: departure.fetch('state') }

        expect_refused(/access_denied/)
      end

      it 'refuses a UserInfo that speaks of another agent' do
        stub_pro_connect
        stub_pro_connect_userinfo({ 'sub' => 'un-autre', 'email' => ProConnectStubs::AGENT_EMAIL })
        departure = depart_for_pro_connect
        stub_pro_connect_tokens(signed_by_pro_connect(pro_connect_id_token_claims(nonce: departure.fetch('nonce'))))

        get admin_pro_connect_retour_connexion_path, params: { code: 'un-code', state: departure.fetch('state') }

        expect_refused(/même agent/)
      end

      it 'refuses a return nothing departed for' do
        stub_pro_connect

        get admin_pro_connect_retour_connexion_path, params: { code: 'un-code', state: 'x' * 32 }

        expect_refused(/state/)
      end
    end
  end
end
