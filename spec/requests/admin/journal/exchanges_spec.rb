require 'rails_helper'

RSpec.describe 'Admin::Exchanges' do
  describe 'both halves of the four-corner model' do
    before { sign_in }

    # Both halves of the four-corner model, on one listing: what France asks,
    # and what is asked of it.
    describe 'an exchange France did not open' do
      it 'holds its line, and says which way it goes' do
        create(:exchange, :delivered, incoming: true, exchange_id: 'venue-d-ailleurs',
          country_code: nil, procedure_code: nil, evidence_requester_id: nil)

        get admin_journal_exchanges_path

        expect(response.body).to include('venue-d-ailleurs')
        expect(response.body).to include(I18n.t('admin.journal.exchanges.directions.incoming'))
      end

      # Three columns a received exchange may not carry: unguarded, the link to
      # the procedure would raise on the whole page.
      # The procedure belongs to the country that requests: France when it asks,
      # the correspondent when the correspondent asks. `R-EDM-REQ-C073` means its
      # request usually names it — leaving the case where the agent itself could
      # not be read.
      it 'leaves the procedure without a flag when the requester is a correspondent' do
        exchange = create(:exchange, :delivered, incoming: true, country_code: nil,
          procedure_code: ProcedureCode::SYSTEM_CHECK)

        get admin_journal_exchange_path(exchange.exchange_id)

        expect(response.body).not_to include(admin_common_services_procedure_country_path(
          ProcedureCode::SYSTEM_CHECK, Settings.common_services_country_code,
        ))
      end

      # The solicited country, on the other hand, is always known: France when
      # France is queried, the correspondent when France asks.
      it 'names France as the country the evidence is asked of' do
        exchange = create(:exchange, :delivered, incoming: true, country_code: 'BE')

        get admin_journal_exchange_path(exchange.exchange_id)

        expect(response.body).to include(I18n.t('admin.solicited_country'))
        expect(response.body).to include(CountryTagComponent.flag(Settings.common_services_country_code))
      end

      it 'renders its page with none of what only an outgoing exchange knows' do
        exchange = create(:exchange, incoming: true, country_code: nil, procedure_code: nil,
          evidence_requester_id: nil)

        get admin_journal_exchange_path(exchange.exchange_id)

        expect(response).to have_http_status(:ok)
      end
    end

    # The detail page carries the exchange's log. The message identifier is read
    # on the event's own page alone: the table keeps it back.
    it 'shows what the journal retains of the exchange' do
      exchange = create(:exchange, :delivered)
      event = create(:audit_event, event_type: 'evidence_delivered',
        exchange_id: exchange.exchange_id)

      get admin_journal_exchange_path(exchange.exchange_id)

      expect(response.body).to include(I18n.t('admin.journal.event_types.evidence_delivered'))
      expect(response.body).to include(admin_journal_event_path(event))
    end
  end

  describe 'GET /admin/journal/exchanges' do
    before { sign_in }

    it 'says where the reader stands' do
      get admin_journal_exchanges_path

      expect(response.parsed_body.css(".fr-breadcrumb__link[aria-current='true']").text)
        .to eq(I18n.t('admin.journal.exchanges.index.title'))
    end

    it 'lists the exchanges, most recent first' do
      older = create(:exchange, :delivered, created_at: 2.days.ago)
      newer = create(:exchange, :failed, created_at: 1.hour.ago)

      get admin_journal_exchanges_path

      expect(response).to have_http_status(:ok)
      expect(response.body.index(newer.exchange_id))
        .to be < response.body.index(older.exchange_id)
    end

    it 'narrows on a status' do
      delivered = create(:exchange, :delivered)
      failed = create(:exchange, :failed)

      get admin_journal_exchanges_path(status: 'delivered')

      expect(response.body).to include(delivered.exchange_id)
      expect(response.body).not_to include(failed.exchange_id)
    end

    it 'narrows on the country, whatever its case' do
      finnish = create(:exchange, country_code: 'FI')
      french = create(:exchange, country_code: 'FR')

      get admin_journal_exchanges_path(country_code: 'fi')

      expect(response.body).to include(finnish.exchange_id)
      expect(response.body).not_to include(french.exchange_id)
    end

    it 'narrows on the requester' do
      wanted = create(:exchange, evidence_requester_id: '11111111111111')
      other = create(:exchange, evidence_requester_id: '22222222222222')

      get admin_journal_exchanges_path(evidence_requester_id: '11111111111111')

      expect(response.body).to include(wanted.exchange_id)
      expect(response.body).not_to include(other.exchange_id)
    end

    it 'narrows on the conversation' do
      session = '5fe50e16-d6b8-4005-b5ec-0ab097f34448'
      wanted = create(:exchange, conversation_id: session)
      other = create(:exchange)

      get admin_journal_exchanges_path(conversation_id: session)

      expect(response.body).to include(wanted.exchange_id)
      expect(response.body).not_to include(other.exchange_id)
    end

    it 'narrows on the procedure' do
      wanted = create(:exchange, procedure_code: '00')
      other = create(:exchange, procedure_code: '01')

      get admin_journal_exchanges_path(procedure_code: '00')

      expect(response.body).to include(wanted.exchange_id)
      expect(response.body).not_to include(other.exchange_id)
    end

    it 'narrows on a period' do
      old = create(:exchange, created_at: 10.days.ago)
      recent = create(:exchange, created_at: 1.day.ago)

      get admin_journal_exchanges_path(depuis: 3.days.ago.to_date.iso8601)

      expect(response.body).to include(recent.exchange_id)
      expect(response.body).not_to include(old.exchange_id)
    end

    # Dropping a criterion would show every exchange under a heading claiming
    # otherwise, and nothing on screen tells the two apart.
    describe 'a criterion it cannot honour' do
      it 'shows nothing for a status the model does not have, and says so' do
        exchange = create(:exchange, :delivered)

        get admin_journal_exchanges_path(status: 'livree')

        expect(response.body).not_to include(exchange.exchange_id)
        expect(response.parsed_body.css('.fr-alert--error')).not_to be_empty
      end

      # The alert is looked for by its class rather than by its wording, which
      # belongs to a locale file and may be rephrased without the behaviour
      # changing.
      it 'shows nothing for a date it cannot read, and says so' do
        exchange = create(:exchange, :delivered)

        get admin_journal_exchanges_path(depuis: 'pas-une-date')

        expect(response.body).not_to include(exchange.exchange_id)
        expect(response.parsed_body.css('.fr-alert--error')).not_to be_empty
      end

      it 'says so when the period is read the wrong way round' do
        create(:exchange, :delivered)

        get admin_journal_exchanges_path(depuis: '2026-08-20', jusqu_a: '2026-08-10')

        expect(response.parsed_body.css('.fr-alert--error')).not_to be_empty
      end
    end

    describe 'paging' do
      it 'offers pagination beyond one page' do
        create_list(:exchange, ExchangeFilter::PER_PAGE + 1, :delivered)

        get admin_journal_exchanges_path

        expect(response.body).to include('fr-pagination')
      end

      it 'carries the active criteria into the page links' do
        create_list(:exchange, ExchangeFilter::PER_PAGE + 1, :failed)

        get admin_journal_exchanges_path(status: 'failed')

        expect(response.body).to include(CGI.escapeHTML(admin_journal_exchanges_path(status: 'failed', page: 2)))
      end

      # PostgreSQL refuses an offset wider than a 64-bit integer, and answered
      # this with a 500 before the page was clamped.
      it 'survives a page number no database could offset to' do
        create(:exchange, :delivered)

        get admin_journal_exchanges_path(page: '99999999999999999999999999')

        expect(response).to have_http_status(:ok)
      end

      it 'never claims a total it does not show' do
        create(:exchange, :delivered)

        get admin_journal_exchanges_path(page: 999_999)

        expect(response.body).not_to include(I18n.t('admin.journal.exchanges.index.empty'))
      end
    end
  end

  describe 'GET /admin/journal/exchanges/:id' do
    before { sign_in }

    it 'shows why an exchange failed, which nothing else exposes' do
      exchange = create(:exchange, :failed)

      get admin_journal_exchange_path(exchange.exchange_id)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(exchange.edm_error_code)
      expect(response.body).to include(CGI.escapeHTML(exchange.error_description))
    end

    # An identifier shown with no way to follow it says nothing: the row leads
    # to the other exchanges of the same user's session, which is what chapter
    # 4.7 gives the conversation identifier for.
    it 'leads from an exchange to the rest of its conversation' do
      exchange = create(:exchange)

      get admin_journal_exchange_path(exchange.exchange_id)

      expect(response.body).to include(exchange.conversation_id)
      expect(response.body).to include(admin_journal_exchanges_path(conversation_id: exchange.conversation_id))
    end

    it 'shows a dash where an exchange has nothing to show' do
      exchange = create(:exchange, :sent)

      get admin_journal_exchange_path(exchange.exchange_id)

      expect(response.body).to include('—')
    end

    # A foreign correspondent chooses this address: it is read, not followed.
    it 'offers the preview address as text and never as a link' do
      exchange = create(:exchange, :preview_required)

      get admin_journal_exchange_path(exchange.exchange_id)

      expect(response.body).to include(exchange.preview_location)
      expect(response.parsed_body.css("a[href='#{exchange.preview_location}']")).to be_empty
    end

    it 'escapes what a correspondent wrote' do
      exchange = create(:exchange, :preview_required,
        preview_location: 'https://example.fi/"><script>alert(1)</script>')

      get admin_journal_exchange_path(exchange.exchange_id)

      expect(response.body).not_to include('<script>alert(1)</script>')
    end

    it 'answers 404 for an unknown exchange' do
      get admin_journal_exchange_path('inconnue')

      expect(response).to have_http_status(:not_found)
    end
  end

  # The redirect is followed before asserting the absence of the data: the body
  # of a redirect is Rails' generic stub, which never carries the guarded page
  # whether the guard fired or not, so asserting on it would prove nothing.
  describe 'without a session' do
    it 'shows no exchange and sends the visitor to the login page' do
      exchange = create(:exchange, :failed)

      get admin_journal_exchanges_path

      expect(response).to have_http_status(:see_other)
      expect(response).to redirect_to(new_admin_session_path)

      follow_redirect!
      expect(response.body).not_to include(exchange.exchange_id)
    end

    it 'sends the visitor to the login page rather than to one exchange' do
      exchange = create(:exchange, :failed)

      get admin_journal_exchange_path(exchange.exchange_id)

      expect(response).to redirect_to(new_admin_session_path)

      follow_redirect!
      expect(response.body).not_to include(CGI.escapeHTML(exchange.error_description))
    end
  end
end
