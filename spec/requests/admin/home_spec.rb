require 'rails_helper'

RSpec.describe 'Admin::Home' do
  describe 'GET /admin' do
    before { sign_in_as_administrator }

    it 'leads to each view of the space' do
      get admin_root_path

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.css("a[href='#{admin_common_services_root_path}']")).not_to be_empty
      expect(response.parsed_body.css("a[href='#{admin_journal_root_path}']")).not_to be_empty
      expect(response.parsed_body.css("a[href='#{admin_jobs_path}']")).not_to be_empty
      expect(response.parsed_body.css("a[href='#{admin_demo_root_path}']")).not_to be_empty
    end

    it 'shows the address of the signed-in agent in the header' do
      get admin_root_path

      expect(response.parsed_body.css('.fr-header__tools-links').text).to include(ProConnectStubs::AGENT_EMAIL)
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

  describe 'GET /admin for an agent nobody named administrator' do
    before { sign_in }

    it 'offers the directories and the demonstration, and nothing else' do
      get admin_root_path

      tiles = response.parsed_body.css('.fr-tile a').pluck('href')
      expect(tiles).to eq([admin_common_services_root_path, admin_demo_root_path])
    end

    it 'leaves the journal and the jobs out of the header' do
      get admin_root_path

      header = response.parsed_body.css('header')
      expect(header.css("a[href='#{admin_common_services_root_path}']")).not_to be_empty
      expect(header.css("a[href='#{admin_demo_root_path}']")).not_to be_empty
      expect(header.css("a[href='#{admin_journal_root_path}']")).to be_empty
      expect(header.css("a[href='#{admin_jobs_path}']")).to be_empty
    end
  end

  describe 'GET /admin without a session' do
    it 'sends the visitor to the login page' do
      get admin_root_path

      expect(response).to redirect_to(new_admin_session_path)
    end
  end
end
