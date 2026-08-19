require 'rails_helper'

RSpec.describe AuditEvent do
  subject(:event) { create(:audit_event) }

  it { is_expected.to validate_presence_of(:occurred_at) }
  it { is_expected.to validate_inclusion_of(:event_type).in_array(described_class::EVENT_TYPES) }

  # The trace is what an audit rests on, and one that can be rewritten after the
  # fact rests on nothing.
  it 'refuses to be rewritten once written' do
    expect { event.update!(detail: 'autre chose') }.to raise_error(ActiveRecord::ReadOnlyRecord)
  end

  describe 'the personal data it carries' do
    subject(:event) { create(:audit_event, :about_a_person) }

    # Chapter 4.8 names the evidence subject among what must be logged, and the
    # log outlives the exchange by twelve months: a database dump must not hand
    # over who asked for what.
    it 'is unreadable in the column that holds it' do
      stored = described_class.connection.select_value(
        "SELECT evidence_subject FROM audit_events WHERE id = #{event.id}",
      )

      expect(stored).not_to include('Königreich')
      expect(event.reload.evidence_subject).to include('Königreich')
    end

    # What prefills the search from an event's page, taken from the subject and
    # not from the key, whose case `subject_key` has folded away.
    it 'hands back the criteria that find the same person' do
      expect(event.subject_criteria).to eq(family_name: 'Königreich', given_name: 'Ada', date_of_birth: '1990-01-01')
    end

    # Deterministic, and only on this column: it is what article 17 is for —
    # answering which of a person's data travelled — and what chantier 5 will
    # compare a response against.
    it 'can still be looked up by subject' do
      expect(described_class.where(evidence_subject_key: 'königreich|ada|1990-01-01')).to contain_exactly(event)
    end
  end

  # It lives on the model because three callers share it: the writing, the
  # search, and the comparison chantier 5 will make against a response.
  describe '.subject_key' do
    it 'folds the case, so one person yields one key' do
      expect(described_class.subject_key(family_name: 'DUPONT', given_name: 'Sophie', date_of_birth: '1965-11-25'))
        .to eq('dupont|sophie|1965-11-25')
    end
  end

  it 'upcases the country whoever wrote it' do
    expect(create(:audit_event, country_code: 'be').country_code).to eq('BE')
  end
end
