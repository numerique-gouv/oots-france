require 'rails_helper'

# The dashboard is a mounted engine: none of this application's filters apply
# to it, and only a real request proves it is wired in at all.
RSpec.describe 'Admin::Jobs' do
  describe 'GET /admin/jobs' do
    it 'serves the GoodJob dashboard' do
      get admin_jobs_path
      follow_redirect! while response.redirect?

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('GoodJob')
    end
  end
end
