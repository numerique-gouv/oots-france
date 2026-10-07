require 'rails_helper'

# What an agent ProConnect admits, but nobody named administrator, meets on the
# journal, the jobs and the access points; and how naming or dismissing them
# takes effect at the next request.
RSpec.describe 'Admin::RestrictedAccess' do
  let(:exchange) { create(:exchange, :failed) }

  # Named through the application's own helpers: after a request into the jobs
  # engine, the spec's helpers prefix every path with the engine's mount point.
  def expect_refusal
    expect(response).to have_http_status(:see_other)
    expect(response).to redirect_to(Rails.application.routes.url_helpers.admin_restricted_access_path)
  end

  describe 'for an agent nobody named administrator' do
    before { sign_in }

    {
      'the journal' => -> { admin_journal_root_path },
      'an event' => -> { admin_journal_event_path(create(:audit_event)) },
      'an exchange' => -> { admin_journal_exchange_path(exchange.exchange_id) },
      'a conversation' => -> { admin_journal_conversation_path(exchange.conversation_id) },
      'the search by subject' => -> { admin_journal_subjects_path(family_name: 'Dupont') },
      'the jobs dashboard' => -> { admin_jobs_path },
      'the access points' => -> { admin_common_services_access_points_path },
    }.each do |name, path|
      it "refuses #{name}" do
        get instance_exec(&path)

        expect_refusal
      end
    end

    it 'refuses a retry from the jobs dashboard with a 303, which its Turbo follows' do
      put "#{admin_jobs_path}/jobs/#{SecureRandom.uuid}/retry"

      expect_refusal
    end

    it 'starts no connectivity test' do
      expect { post admin_common_services_connectivity_tests_path, params: { fragment: 1 } }
        .not_to have_enqueued_job(SubmitConnectivityTestJob)

      expect_refusal
      expect(ConnectivityTest.count).to eq(0)
    end

    it 'says who to ask, in a page of the console' do
      get admin_journal_root_path
      follow_redirect!

      expect(response).to have_http_status(:forbidden)
      expect(response.parsed_body.css('h1').text).to eq('Accès réservé')
      expect(response.parsed_body.css('main').text.squish).to include(
        "Cette page est réservée aux administrateurs nommés par l'équipe qui exploite le service.",
        "Demandez-lui d'être nommé administrateur.",
      )
    end

    it 'opens the journal at the next request once the address is named' do
      Administrator.appoint(ProConnectStubs::AGENT_EMAIL.upcase)

      get admin_journal_root_path

      expect(response).to have_http_status(:ok)
    end
  end

  describe 'for an administrator dismissed during the session' do
    before { sign_in_as_administrator }

    it 'refuses the jobs dashboard at the next request' do
      Administrator.dismiss(ProConnectStubs::AGENT_EMAIL)

      get admin_jobs_path

      expect_refusal
    end
  end

  describe 'without a session' do
    it 'sends the visitor to the login page' do
      get admin_restricted_access_path

      expect(response).to redirect_to(new_admin_session_path)
    end
  end
end
