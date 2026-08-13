require 'rails_helper'

RSpec.describe 'Admin::Conversations' do
  describe 'GET /admin/conversations' do
    it 'lists the exchanges, most recent first' do
      older = create(:conversation, :delivered, created_at: 2.days.ago)
      newer = create(:conversation, :failed, created_at: 1.hour.ago)

      get admin_conversations_path

      expect(response).to have_http_status(:ok)
      expect(response.body.index(newer.conversation_id))
        .to be < response.body.index(older.conversation_id)
    end

    it 'narrows on a status' do
      delivered = create(:conversation, :delivered)
      failed = create(:conversation, :failed)

      get admin_conversations_path(status: 'delivered')

      expect(response.body).to include(delivered.conversation_id)
      expect(response.body).not_to include(failed.conversation_id)
    end

    it 'narrows on the country, whatever its case' do
      finnish = create(:conversation, country_code: 'FI')
      french = create(:conversation, country_code: 'FR')

      get admin_conversations_path(country_code: 'fi')

      expect(response.body).to include(finnish.conversation_id)
      expect(response.body).not_to include(french.conversation_id)
    end

    it 'narrows on the requester' do
      wanted = create(:conversation, evidence_requester_id: '11111111111111')
      other = create(:conversation, evidence_requester_id: '22222222222222')

      get admin_conversations_path(evidence_requester_id: '11111111111111')

      expect(response.body).to include(wanted.conversation_id)
      expect(response.body).not_to include(other.conversation_id)
    end

    it 'narrows on the procedure' do
      wanted = create(:conversation, procedure_code: '00')
      other = create(:conversation, procedure_code: '01')

      get admin_conversations_path(procedure_code: '00')

      expect(response.body).to include(wanted.conversation_id)
      expect(response.body).not_to include(other.conversation_id)
    end

    it 'narrows on a period' do
      old = create(:conversation, created_at: 10.days.ago)
      recent = create(:conversation, created_at: 1.day.ago)

      get admin_conversations_path(depuis: 3.days.ago.to_date.iso8601)

      expect(response.body).to include(recent.conversation_id)
      expect(response.body).not_to include(old.conversation_id)
    end

    # Dropping a criterion would show every exchange under a heading claiming
    # otherwise, and nothing on screen tells the two apart.
    describe 'a criterion it cannot honour' do
      it 'shows nothing for a status the model does not have, and says so' do
        conversation = create(:conversation, :delivered)

        get admin_conversations_path(status: 'livree')

        expect(response.body).not_to include(conversation.conversation_id)
        expect(response.parsed_body.css('.fr-alert--error')).not_to be_empty
      end

      # The alert is looked for by its class rather than by its wording, which
      # belongs to a locale file and may be rephrased without the behaviour
      # changing.
      it 'shows nothing for a date it cannot read, and says so' do
        conversation = create(:conversation, :delivered)

        get admin_conversations_path(depuis: 'pas-une-date')

        expect(response.body).not_to include(conversation.conversation_id)
        expect(response.parsed_body.css('.fr-alert--error')).not_to be_empty
      end

      it 'says so when the period is read the wrong way round' do
        create(:conversation, :delivered)

        get admin_conversations_path(depuis: '2026-08-20', jusqu_a: '2026-08-10')

        expect(response.parsed_body.css('.fr-alert--error')).not_to be_empty
      end
    end

    describe 'paging' do
      it 'offers pagination beyond one page' do
        create_list(:conversation, ConversationFilter::PER_PAGE + 1, :delivered)

        get admin_conversations_path

        expect(response.body).to include('fr-pagination')
      end

      it 'carries the active criteria into the page links' do
        create_list(:conversation, ConversationFilter::PER_PAGE + 1, :failed)

        get admin_conversations_path(status: 'failed')

        expect(response.body).to include(CGI.escapeHTML(admin_conversations_path(status: 'failed', page: 2)))
      end

      # PostgreSQL refuses an offset wider than a 64-bit integer, and answered
      # this with a 500 before the page was clamped.
      it 'survives a page number no database could offset to' do
        create(:conversation, :delivered)

        get admin_conversations_path(page: '99999999999999999999999999')

        expect(response).to have_http_status(:ok)
      end

      it 'never claims a total it does not show' do
        create(:conversation, :delivered)

        get admin_conversations_path(page: 999_999)

        expect(response.body).not_to include('Aucune conversation ne correspond')
      end
    end
  end

  describe 'GET /admin/conversations/:id' do
    it 'shows why an exchange failed, which nothing else exposes' do
      conversation = create(:conversation, :failed)

      get admin_conversation_path(conversation.conversation_id)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(conversation.edm_error_code)
      expect(response.body).to include(CGI.escapeHTML(conversation.error_description))
    end

    it 'shows a dash where an exchange has nothing to show' do
      conversation = create(:conversation, :sent)

      get admin_conversation_path(conversation.conversation_id)

      expect(response.body).to include('—')
    end

    # A foreign correspondent chooses this address: it is read, not followed.
    it 'offers the preview address as text and never as a link' do
      conversation = create(:conversation, :preview_required)

      get admin_conversation_path(conversation.conversation_id)

      expect(response.body).to include(conversation.preview_location)
      expect(response.parsed_body.css("a[href='#{conversation.preview_location}']")).to be_empty
    end

    it 'escapes what a correspondent wrote' do
      conversation = create(:conversation, :preview_required,
        preview_location: 'https://example.fi/"><script>alert(1)</script>')

      get admin_conversation_path(conversation.conversation_id)

      expect(response.body).not_to include('<script>alert(1)</script>')
    end

    it 'answers 404 for an unknown conversation' do
      get admin_conversation_path('inconnue')

      expect(response).to have_http_status(:not_found)
    end
  end
end
