require 'rails_helper'

RSpec.describe 'Admin::Exchanges' do
  describe 'both halves of the four-corner model' do
    before { sign_in }

    # Both halves of the four-corner model, on one listing: what France asks,
    # and what is asked of it.
    describe 'an exchange France did not open' do
      it 'says which way it goes' do
        exchange = create(:exchange, :delivered, incoming: true,
          country_code: nil, procedure_code: nil, evidence_requester_id: nil)

        get admin_journal_exchange_path(exchange.exchange_id)

        expect(response.body).to include(exchange.exchange_id)
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

    # What an operator has to be able to read of a deferred exchange: chapter
    # 4.5.2 announces a date, and the exchange is settled on it rather than
    # failed.
    describe 'an exchange a correspondent deferred' do
      it 'reads the announced date on the page' do
        exchange = create(:exchange, :deferred,
          response_available_at: Time.zone.parse('2026-09-01T08:00:00Z'))

        get admin_journal_exchange_path(exchange.exchange_id)

        expect(response.body).to include(I18n.t('admin.journal.exchanges.show.rows.response_available_at'))
        expect(response.body).to include(I18n.l(exchange.response_available_at, format: :long))
        expect(response.body).to include(I18n.t('admin.journal.exchanges.statuses.deferred'))
      end

      # The row is unconditional, so an exchange nobody deferred shows the
      # heading and no date — never a blank the reader has to interpret.
      it 'keeps the row, empty, on an exchange nobody deferred' do
        exchange = create(:exchange, :delivered)

        get admin_journal_exchange_path(exchange.exchange_id)

        expect(response.body).to include(I18n.t('admin.journal.exchanges.show.rows.response_available_at'))
        expect(response.body).not_to include(I18n.t('admin.journal.exchanges.statuses.deferred'))
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
      expect(response.body).to include(admin_journal_conversation_path(exchange.conversation_id))
    end

    it 'shows a dash where an exchange has nothing to show' do
      exchange = create(:exchange, :sent)

      get admin_journal_exchange_path(exchange.exchange_id)

      expect(response.body).to include('—')
    end

    it 'opens the preview address rather than leave it to be copied by hand' do
      exchange = create(:exchange, :preview_required)

      get admin_journal_exchange_path(exchange.exchange_id)

      lien = response.parsed_body.at_css("a[href='#{exchange.preview_location}']")

      expect(lien).to be_present
      expect(lien[:rel]).to include('noopener')
    end

    # A correspondent chooses this address, and `link_to` escapes the HTML
    # without ever looking at the scheme: `javascript:` in an `href` would run
    # on our own origin.
    it 'refuses to make an address a browser cannot open into a link' do
      exchange = create(:exchange, :preview_required)
      exchange.update_column(:preview_location, 'javascript:alert(1)')

      get admin_journal_exchange_path(exchange.exchange_id)

      expect(response.body).to include('javascript:alert(1)')
      expect(response.parsed_body.css('a[href^="javascript:"]')).to be_empty
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
    it 'sends the visitor to the login page rather than to one exchange' do
      exchange = create(:exchange, :failed)

      get admin_journal_exchange_path(exchange.exchange_id)

      expect(response).to redirect_to(new_admin_session_path)

      follow_redirect!
      expect(response.body).not_to include(CGI.escapeHTML(exchange.error_description))
    end
  end
end
