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
      post admin_demo_identification_path

      expect(response.headers['Location']).to start_with("#{FranceConnectStubs::AUTHORIZATION_ENDPOINT}?")
      expect(session[:france_connect].symbolize_keys.keys).to contain_exactly(:state, :nonce)
    end

    it 'departs afresh each time, rather than replaying a state already spent' do
      post admin_demo_identification_path
      first = session[:france_connect].symbolize_keys.fetch(:state)

      post admin_demo_identification_path

      expect(session[:france_connect].symbolize_keys.fetch(:state)).not_to eq(first)
    end

    # Nothing is held, and the operator is told: `docs/espace_administration.md`
    # names the console's audience, and this is the one page of the demonstration
    # they can act on.
    it 'sends the operator back to the procedure, saying why, when the portal cannot be reached' do
      stub_code_list
      stub_request(:get, FranceConnectStubs::DISCOVERY_URL).to_timeout

      post admin_demo_identification_path

      expect(response).to redirect_to(admin_demo_root_path)
      follow_redirect!
      expect(response.parsed_body.css('.fr-alert').text)
        .to include("L'identification par FranceConnect+ n'a pas abouti", 'découverte')
    end
  end

  describe 'POST /admin/demo/identification without a session' do
    it 'sends the visitor to the login page' do
      post admin_demo_identification_path

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
