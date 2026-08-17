require 'rails_helper'

RSpec.describe 'Admin::Home' do
  describe 'GET /admin' do
    before { sign_in }

    it 'leads to both views of the space' do
      get admin_root_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(admin_conversations_path)
      expect(response.body).to include(admin_jobs_path)
    end

    it 'carries the navigation' do
      get admin_root_path

      expect(response.parsed_body.css('.fr-nav')).not_to be_empty
    end

    it 'offers a way out' do
      get admin_root_path

      expect(response.parsed_body.css("form[action='#{admin_session_path}']")).not_to be_empty
    end
  end

  describe 'GET /admin without a session' do
    it 'sends the visitor to the login page' do
      get admin_root_path

      expect(response).to redirect_to(new_admin_session_path)
    end
  end
end
