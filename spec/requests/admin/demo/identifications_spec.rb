require 'rails_helper'

RSpec.describe 'Admin::Demo::Identifications' do
  describe 'GET /admin/demo/identification' do
    before { sign_in }

    # The button leads somewhere, which is what the page owes its reader until
    # OOTS-179 puts the European flow of FranceConnect+ behind it.
    it 'says the sign-in is not wired yet' do
      get admin_demo_identification_path

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.css('main').text)
        .to include("L'identification par FranceConnect+ n'est pas encore branchée")
    end

    it 'leads back to the procedure' do
      get admin_demo_identification_path

      expect(response.parsed_body.css("a[href='#{admin_demo_root_path}']")).not_to be_empty
    end
  end

  describe 'GET /admin/demo/identification without a session' do
    it 'sends the visitor to the login page' do
      get admin_demo_identification_path

      expect(response).to redirect_to(new_admin_session_path)
    end
  end
end
