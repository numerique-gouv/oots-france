require 'rails_helper'

# Chapter 4.4 makes a conversation an identifier several exchanges share, not a
# record this application opens. The page is therefore built from the exchanges
# that name it — and it is what the console offers in place of a listing of
# exchanges, which no question starts from.
RSpec.describe 'Admin::Journal::Conversations' do
  let(:conversation_id) { '5fe50e16-d6b8-4005-b5ec-0ab097f34448' }

  describe 'GET /admin/journal/conversations/:id' do
    before { sign_in }

    it 'gathers the exchanges of one session, most recently opened last' do
      first = create(:exchange, :delivered, conversation_id:, created_at: 2.days.ago)
      second = create(:exchange, :failed, conversation_id:, created_at: 1.hour.ago)
      elsewhere = create(:exchange)

      get admin_journal_conversation_path(conversation_id)

      expect(response.body).to include(first.exchange_id).and include(second.exchange_id)
      expect(response.body).not_to include(elsewhere.exchange_id)
      expect(response.body.index(first.exchange_id)).to be < response.body.index(second.exchange_id)
    end

    # One table per exchange, and not one merged listing: which event belongs to
    # which round trip is the whole point of the page.
    it 'gives each exchange its own journal' do
      first = create(:exchange, conversation_id:)
      second = create(:exchange, conversation_id:)
      create(:audit_event, event_type: 'request_sent', exchange_id: first.exchange_id, conversation_id:)
      create(:audit_event, event_type: 'error_received', exchange_id: second.exchange_id, conversation_id:)

      get admin_journal_conversation_path(conversation_id)

      expect(response.parsed_body.css('table').size).to eq(2)
      expect(response.body).to include(I18n.t('admin.journal.event_types.request_sent'))
      expect(response.body).to include(I18n.t('admin.journal.event_types.error_received'))
    end

    it 'says so where an exchange has left no event yet' do
      create(:exchange, :sent, conversation_id:)

      get admin_journal_conversation_path(conversation_id)

      expect(response.body).to include(I18n.t('admin.journal.conversations.show.empty'))
    end

    it 'leads to each exchange' do
      exchange = create(:exchange, conversation_id:)

      get admin_journal_conversation_path(conversation_id)

      expect(response.body).to include(admin_journal_exchange_path(exchange.exchange_id))
    end

    # A conversation nothing names never happened: answered like an exchange
    # nobody opened, rather than as an empty page that would read as a session
    # with no exchanges.
    it 'answers 404 for a conversation no exchange names' do
      get admin_journal_conversation_path('5fe50e16-d6b8-4005-b5ec-000000000000')

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'without a session' do
    it 'sends the visitor to the login page' do
      exchange = create(:exchange, conversation_id:)

      get admin_journal_conversation_path(conversation_id)

      expect(response).to have_http_status(:see_other)
      expect(response).to redirect_to(new_admin_session_path)

      follow_redirect!
      expect(response.body).not_to include(exchange.exchange_id)
    end
  end
end
