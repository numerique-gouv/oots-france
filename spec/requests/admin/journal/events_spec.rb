require 'rails_helper'

RSpec.describe 'Admin::Journal::Events' do
  before { sign_in }

  describe 'GET /admin/journal' do
    # An equality and not a presence: the DSFR marks as current whatever crumb
    # carries no address, so two of them would read as two places at once.
    it 'says where the reader stands' do
      get admin_journal_root_path

      expect(response.parsed_body.css(".fr-breadcrumb__link[aria-current='true']").text)
        .to eq(I18n.t('admin.journal.events.index.title'))
    end

    it 'leads to the search by person' do
      get admin_journal_root_path

      expect(response.parsed_body.css("a[href='#{admin_journal_subjects_path}']")).not_to be_empty
    end

    it 'lists the events, most recent first' do
      older = create(:audit_event, occurred_at: 2.days.ago, exchange_id: 'ancienne')
      newer = create(:audit_event, occurred_at: 1.hour.ago, exchange_id: 'recente')

      get admin_journal_root_path

      expect(response).to have_http_status(:ok)
      expect(response.body.index(newer.exchange_id)).to be < response.body.index(older.exchange_id)
    end

    # A refusal never opens an exchange, and a crash between journalling an
    # arrival and opening its own leaves the same shape. A listing built by
    # joining would make either disappear, which is why this page starts from
    # the events.
    it 'shows an exchange that has no local exchange' do
      create(:audit_event, event_type: 'request_received', exchange_id: 'sans-exchange-locale')

      get admin_journal_root_path

      expect(response.body).to include('sans-exchange-locale')
      expect(Exchange.count).to eq(0)
    end

    # What the row carries, without saying which side each stood on: the
    # procedure leads to its page, the country is the correspondent's, and it is
    # for the reader to conclude — the event type says enough.
    it 'leads to the procedure and names the country of the correspondent' do
      create(:audit_event, event_type: 'request_sent', procedure_code: 'S1', country_code: 'FI')

      get admin_journal_root_path

      expect(response.body).to include(admin_common_services_procedure_path('S1'))
      expect(response.body).to include(CountryTagComponent.flag('FI'))
    end

    it 'invents neither where the event recorded neither' do
      create(:audit_event, event_type: 'response_received', procedure_code: nil, country_code: nil,
        exchange_id: 'sans-rien')

      get admin_journal_root_path

      # The listing abbreviates the identifiers, so the row is found by the whole
      # one the link carries in its title rather than by its text.
      ligne = response.parsed_body.css('tbody tr').find { |row| row.to_html.include?('sans-rien') }

      expect(ligne.text).not_to include(CountryTagComponent.flag(Settings.common_services_country_code))
    end

    # The `title` carries the whole identifier whether the label is abbreviated
    # or not, so an assertion on the body proves nothing about which was
    # rendered: the link's own text is the only thing that tells them apart.
    it 'abbreviates the identifiers it lists, keeping the whole one reachable' do
      event = create(:audit_event, exchange_id: 'e0a6a5b7-6b2e-4b9c-9a63-8f0c6d3a1b01')

      get admin_journal_root_path

      montre = response.parsed_body.css("[title='#{event.exchange_id}']").first
      expect(montre.text.strip).to eq('…3a1b01')
    end

    # The conversation page is built from the exchanges naming it and answers 404
    # when none does — so a response naming a conversation France never opened
    # must read as text, exactly as its exchange already does.
    it 'offers no link to a conversation no exchange names' do
      event = create(:audit_event, event_type: 'response_received',
        exchange_id: '88888888-8888-8888-8888-888888888899',
        conversation_id: '5fe50e16-d6b8-4005-b5ec-0ab097f39999')

      get admin_journal_root_path

      expect(response.parsed_body.css("[title='#{event.conversation_id}']")).not_to be_empty
      expect(response.parsed_body.css("a[title='#{event.conversation_id}']")).to be_empty
    end

    it 'narrows on an event type' do
      create(:audit_event, event_type: 'request_sent', exchange_id: 'emise')
      create(:audit_event, event_type: 'error_received', exchange_id: 'refusee')

      get admin_journal_root_path(event_type: 'error_received')

      expect(response.body).to include('refusee')
      expect(response.body).not_to include('emise')
    end

    # The filter refuses it rather than ignoring it: widening a listing under a
    # heading claiming the opposite is what `SubmittedCriteria` exists to stop.
    it 'refuses an unknown event type rather than widening the listing' do
      create(:audit_event, exchange_id: 'visible-sans-filtre')

      get admin_journal_root_path(event_type: 'charabia')

      expect(response.body).not_to include('visible-sans-filtre')
      expect(response.body).to include(CGI.escapeHTML(I18n.t('admin.unreadable')))
    end
  end

  # Rendered, not merely raised: `full_messages` is what looks the translation
  # up, and a missing key takes the whole page down with it.
  it 'names on screen a criterion it could not read' do
    get admin_journal_root_path(procedure_code: %w[a b])

    expect(response.body).to include(CGI.escapeHTML(I18n.t('admin.unreadable')))
    expect(response.body).to include(CGI.escapeHTML(
      I18n.t('activemodel.attributes.audit_event_filter.procedure_code'),
    ))
  end

  it 'names on screen a period read the wrong way round' do
    get admin_journal_root_path(depuis: '2026-08-10', jusqu_a: '2026-08-01')

    expect(response.body).to include(CGI.escapeHTML(
      I18n.t('activemodel.errors.models.audit_event_filter.attributes.jusqu_a.before_start'),
    ))
  end

  # A refusal turned away before any exchange was opened names none, so it
  # carries no link — but the journal still holds it.
  it 'shows a refusal that never opened an exchange' do
    create(:audit_event, event_type: 'request_refused', exchange_id: nil, detail: 'jeton invalide')

    get admin_journal_root_path

    expect(response.body).to include(I18n.t('admin.journal.event_types.request_refused'))
  end

  describe 'GET /admin/journal/events/:id' do
    it 'shows every column the event carries, decrypted subject included' do
      event = create(:audit_event, :about_a_person, message_id: 'message-de-la-passerelle')

      get admin_journal_event_path(event)

      expect(response.body).to include('message-de-la-passerelle', 'Königreich')
    end

    # The counterpart of the listing's abbreviation: a page with room shows the
    # identifier whole, and adding `abbreviated:` here would go unnoticed
    # without this.
    it 'shows the identifier whole, where the listing abbreviates it' do
      event = create(:audit_event, exchange_id: 'e0a6a5b7-6b2e-4b9c-9a63-8f0c6d3a1b01')

      get admin_journal_event_path(event)

      montre = response.parsed_body.css("[title='#{event.exchange_id}']").first
      expect(montre.text.strip).to eq(event.exchange_id)
    end

    # Glossed, as the exchange's own page glosses it: a bare `EDM:ERR:0004` says
    # nothing to whoever meets it during an incident.
    it 'says in French what an EDM code means, and points at the chapter' do
      event = create(:audit_event, event_type: 'error_received', edm_error_code: 'EDM:ERR:0004')

      get admin_journal_event_path(event)

      expect(response.body).to include(I18n.t('components.edm_error_code.codes.EDM:ERR:0004'))
      expect(response.parsed_body.css("a[href='#{EdmErrorCodeComponent::CHAPTER_URL}']")).not_to be_empty
    end

    # A correspondent outside the eight codes gets no link: that chapter defines
    # the eight, and pointing at it would make it say what it does not.
    it 'leaves a code the chapter does not define without a link' do
      event = create(:audit_event, event_type: 'error_received', edm_error_code: 'EDM:ERR:9999')

      get admin_journal_event_path(event)

      expect(response.body).to include('EDM:ERR:9999')
      expect(response.parsed_body.css("a[href='#{EdmErrorCodeComponent::CHAPTER_URL}']")).to be_empty
    end

    # The console shows personal data on this page alone, and nothing in a table
    # of twenty columns would say which two the reader is looking at.
    it 'marks the columns it had to decrypt, and only those' do
      event = create(:audit_event, :about_a_person, message_id: 'message-de-la-passerelle')

      get admin_journal_event_path(event)

      expect(marked_rows(response).map { |row| row.at_css('th').text }).to contain_exactly(
        I18n.t('admin.journal.attributes.evidence_subject'),
        I18n.t('admin.journal.attributes.evidence_subject_key'),
      )
    end

    # The Semantic Repository names an evidence type by a URL; an operator who
    # wants to know what a classification covers should not have to copy it.
    it 'opens the evidence type classification the Semantic Repository names' do
      classification = 'https://sr.acc.oots.tech.ec.europa.eu/evidencetypeclassifications/FR/869a6748'
      event = create(:audit_event, evidence_type_id: classification)

      get admin_journal_event_path(event)

      expect(response.parsed_body.at_css("a[href='#{classification}']")).to be_present
    end

    # It is read off a received message, so it is whatever the correspondent
    # wrote — and `link_to` escapes the HTML without looking at the scheme.
    it 'leaves as text an evidence type identifier a browser cannot open' do
      event = create(:audit_event, evidence_type_id: 'javascript:alert(1)')

      get admin_journal_event_path(event)

      expect(response.body).to include('javascript:alert(1)')
      expect(response.parsed_body.css('a[href^="javascript:"]')).to be_empty
    end

    # Chapter 4.8 has the log keep the message whole; the page is where an
    # auditor reads it back, folded so that it does not push the rest away.
    it 'shows the RegRep document, folded behind a control the keyboard reaches' do
      event = create(:audit_event, :with_regrep_body)

      get admin_journal_event_path(event)

      page = response.parsed_body
      button = page.at_css("button[aria-controls='#{RegrepBodyComponent::REGION_ID}']")

      expect(button).to be_present
      expect(page.at_css("##{RegrepBodyComponent::REGION_ID} pre").text).to include('QueryRequest')
    end

    # The document is bytes a correspondent chose, and the page renders them
    # verbatim: escaped by ERB, never `raw`, or the journal would be a way of
    # running someone else's markup in the console.
    it 'escapes what the correspondent sent' do
      event = create(:audit_event, :with_regrep_body, regrep_body: '<script>alert(1)</script>')

      get admin_journal_event_path(event)

      expect(response.parsed_body.css('script').map(&:text)).not_to include('alert(1)')
      expect(response.body).to include('&lt;script&gt;')
    end

    # No chapter fixes an encoding, so the journal keeps a body that is not valid
    # UTF-8 rather than refuse it. The page is then the one place that cannot show
    # what is not text — and it must degrade, not fall over: a crash here would
    # hold every other column of that event hostage to one.
    it 'renders an event whose body is not valid UTF-8' do
      body = +"<query:QueryRequest>\xE9</query:QueryRequest>"
      event = create(:audit_event, :with_regrep_body, regrep_body: body.force_encoding(Encoding::UTF_8))

      get admin_journal_event_path(event)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.at_css("##{RegrepBodyComponent::REGION_ID} pre").text).to include('QueryRequest')
    end

    it 'marks the document it had to decrypt as it marks the subject' do
      event = create(:audit_event, :with_regrep_body)

      get admin_journal_event_path(event)

      expect(marked_rows(response).map { |row| row.at_css('th').text })
        .to include(I18n.t('admin.journal.attributes.regrep_body'))
    end

    # Most lines of the journal name nobody — a request sent, a refusal — and a
    # padlock on one of those would say the opposite of what it means.
    it 'marks nothing on an event that names no person' do
      create(:audit_event, event_type: 'request_sent').tap do |event|
        get admin_journal_event_path(event)
      end

      expect(marked_rows(response)).to be_empty
    end

    # The two columns coincide with what the model encrypts, so nothing would
    # tell a list written out here from one read off the record. Moving the
    # record's answer proves which of the two the page obeys — and proves at the
    # same time that the mark wraps the column's own reading instead of
    # replacing it, the link surviving under the padlock.
    it 'marks what the record declares encrypted, keeping the column its reading' do
      allow(AuditEvent).to receive(:encrypted_attributes).and_return(Set[:procedure_code])
      event = create(:audit_event, procedure_code: 'S1')

      get admin_journal_event_path(event)

      expect(marked_rows(response).map { |row| row.at_css('th').text })
        .to contain_exactly(I18n.t('admin.journal.attributes.procedure_code'))
      expect(marked_rows(response).first.at_css('.decrypted-value a'))
        .to have_attributes(text: 'S1')
    end

    # The link that prefills the search: `subject_criteria` composes it, from the
    # subject and not from the key, whose case is lost.
    it 'links to what else concerns the same person, with the case unspoilt' do
      event = create(:audit_event, :about_a_person)

      get admin_journal_event_path(event)

      expect(response.body).to include(CGI.escapeHTML(
        admin_journal_subjects_path(family_name: 'Königreich', given_name: 'Ada', date_of_birth: '1990-01-01'),
      ))
    end

    # It carries the only written reason for the refusal, and its exchange does
    # not exist: nothing else leads to it.
    it 'opens the page of a refusal that never opened an exchange' do
      event = create(:audit_event, event_type: 'request_refused', exchange_id: nil,
        detail: 'Le bénéficiaire doit être renseigné')

      get admin_journal_event_path(event)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Le bénéficiaire doit être renseigné')
    end

    it 'answers 404 for an event the journal never wrote' do
      get admin_journal_event_path(id: 0)

      expect(response).to have_http_status(:not_found)
    end
  end

  def marked_rows(response)
    response.parsed_body.css('tbody tr').select { |row| row.at_css('.decrypted-value') }
  end
end
