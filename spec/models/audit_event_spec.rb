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

    # Deterministic, and only on this column: it is what article 17 is for —
    # answering which of a person's data travelled — and what chantier 5 will
    # compare a response against.
    it 'can still be looked up by subject' do
      expect(described_class.where(evidence_subject_key: 'königreich|ada|1990-01-01')).to contain_exactly(event)
    end
  end
end
