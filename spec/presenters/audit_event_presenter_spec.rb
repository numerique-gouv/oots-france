require 'rails_helper'

RSpec.describe AuditEventPresenter do
  subject(:presenter) { described_class.new(event) }

  let(:event) { build(:audit_event) }

  def names = presenter.rows.map(&:name)

  def row(name) = presenter.rows.find { |candidate| candidate.name == name }

  it 'shows only the columns that carry something' do
    expect(names).to eq(%i[occurred_at conversation_id exchange_id evidence_requester_id procedure_code])
  end

  # The badge above the table says it, as an exchange's own page does with its
  # status, so a row repeating it would say the same thing twice.
  it 'leaves out the type, which the page states above the table' do
    expect(names).not_to include(:event_type)
  end

  # The order is the declaration's, and the declaration is in Ruby: what an
  # event happens to carry never reshuffles what it does.
  it 'keeps the declared order whichever columns are filled' do
    event.edm_error_code = 'EDM:ERR:0004'
    event.country_code = 'DE'

    expect(names).to eq(AuditEventPresenter::COLUMNS & names)
  end

  it 'gives each row the wording the journal names it by' do
    expect(row(:exchange_id).label).to eq(I18n.t('admin.journal.attributes.exchange_id'))
  end

  describe 'how a value asks to be read' do
    it 'reads an instant as a date' do
      expect(row(:occurred_at).reading).to eq(:timestamp)
    end

    it 'reads the two identifiers that lead somewhere as the pages they lead to' do
      expect([row(:exchange_id).reading, row(:conversation_id).reading]).to eq(%i[exchange conversation])
    end

    it 'reads an address as an address, wherever it is declared' do
      event.evidence_type_id = 'https://sr.oots.tech.ec.europa.eu/evidencetypeclassifications/FR/x'
      event.preview_location = 'https://example.org/apercu'

      expect([row(:evidence_type_id).reading, row(:preview_location).reading]).to eq(%i[address address])
    end

    it 'reads anything else as the identifier it is' do
      expect(row(:evidence_requester_id).reading).to eq(:identifier)
    end
  end

  # Chapter 4.5.1 describes a subject with repeated and structured attributes,
  # which the one line of JSON the column holds would never make readable.
  it 'hands the subject over parsed, not as the JSON the column holds' do
    subject_event = build(:audit_event, :about_sophie)

    expect(described_class.new(subject_event).rows.find { |r| r.name == :evidence_subject }.value)
      .to include('family_name' => 'Dupont')
  end

  describe 'what the page must mark as decrypted' do
    let(:event) { build(:audit_event, :about_sophie, :with_regrep_body) }

    # Read off the record, never off a list copied into the presenter: a column
    # that becomes encrypted must not need this file edited to be marked.
    it 'marks the columns the record encrypts, and only those' do
      marked = presenter.rows.select(&:encrypted?).map(&:name)

      expect(marked).to match_array(AuditEvent.encrypted_attributes & names)
    end

    # `DecryptedValueComponent` wraps an inline cell in a `<span>`, which neither
    # a folded document nor a definition list can sit inside.
    it 'says which of them are flow content' do
      expect(presenter.rows.select(&:flow?).map(&:name)).to contain_exactly(:evidence_subject, :regrep_body)
    end
  end

  # Bytes a correspondent sent that are not valid UTF-8 — which the journal
  # keeps whole — make `blank?` raise, since it matches a regexp.
  it 'tests emptiness without asking a regexp, on a body that is not valid UTF-8' do
    event.regrep_mime_type = 'application/x-ebrs+xml'
    event.regrep_body = (+"<query:QueryRequest/>\xC3").force_encoding('UTF-8')

    expect(names).to include(:regrep_body)
  end
end
