require 'rails_helper'

RSpec.describe AuditEventFilter do
  def narrowed(criteria) = described_class.new(**criteria).then { |f| f.apply(AuditEvent.all, 1) }

  def submitted(criteria) = described_class.from(ActionController::Parameters.new(criteria))

  it 'orders by when the thing happened, not by when it was written' do
    older = create(:audit_event, occurred_at: 2.days.ago)
    newer = create(:audit_event, occurred_at: 1.hour.ago)

    expect(narrowed({})).to eq([newer, older])
  end

  it 'narrows on an event type' do
    sent = create(:audit_event, event_type: 'request_sent')
    create(:audit_event, event_type: 'error_received')

    expect(narrowed(event_type: 'request_sent')).to contain_exactly(sent)
  end

  it 'upcases the country, as the conversation filter does' do
    finnish = create(:audit_event, country_code: 'FI')

    expect(narrowed(country_code: 'fi')).to contain_exactly(finnish)
  end

  # A criterion it cannot honour narrows to nothing, and the page says which:
  # ignoring one would widen the listing under a heading claiming the opposite.
  it 'narrows to nothing on an event type it does not know' do
    create(:audit_event)

    expect(narrowed(event_type: 'charabia')).to be_empty
  end

  # A country that is not a two-letter code narrows to nothing, and an empty
  # listing alone would not tell an operator that the code was the problem.
  it 'refuses a country that is not a two-letter code' do
    create(:audit_event, country_code: 'FI')
    refused = described_class.new(country_code: 'FRANCE')

    expect(refused.apply(AuditEvent.all, 1)).to be_empty
    expect(refused.errors.full_messages).to include(
      /#{I18n.t('activemodel.errors.models.audit_event_filter.attributes.country_code.format')}/,
    )
  end

  it 'narrows on the procedure alone' do
    procedure = create(:audit_event, procedure_code: '01')
    create(:audit_event, procedure_code: '02')

    expect(narrowed(procedure_code: '01')).to contain_exactly(procedure)
  end

  it 'narrows on the requester alone' do
    requester = create(:audit_event, evidence_requester_id: '00000000000009')
    create(:audit_event, evidence_requester_id: '00000000000002')

    expect(narrowed(evidence_requester_id: '00000000000009')).to contain_exactly(requester)
  end

  describe 'the period' do
    # On `occurred_at`, not on `created_at`: an event written today may relate
    # something that happened last week.
    it 'is closed at both ends when both are given' do
      inside = create(:audit_event, occurred_at: Date.new(2026, 8, 10).noon)
      create(:audit_event, occurred_at: Date.new(2026, 8, 20).noon)

      expect(narrowed(depuis: Date.new(2026, 8, 9), jusqu_a: Date.new(2026, 8, 11))).to contain_exactly(inside)
    end

    it 'stays open at the end when only a start is given' do
      later = create(:audit_event, occurred_at: Date.new(2026, 8, 20).noon)
      create(:audit_event, occurred_at: Date.new(2026, 8, 1).noon)

      expect(narrowed(depuis: Date.new(2026, 8, 10))).to contain_exactly(later)
    end

    it 'refuses a period read the wrong way round' do
      refused = described_class.new(depuis: Date.new(2026, 8, 10), jusqu_a: Date.new(2026, 8, 1))

      expect(refused.tap(&:valid?).errors).to be_of_kind(:jusqu_a, :before_start)
    end
  end

  # The criterion was submitted and lost on the way in — `ActiveModel::Type::Date`
  # answers nil for a string it cannot read. Read as one nobody submitted, it
  # would widen the listing instead of narrowing it.
  it 'narrows to nothing on a date it cannot read, and says which criterion' do
    create(:audit_event)
    refused = submitted(depuis: 'pas-une-date')

    expect(refused.apply(AuditEvent.all, 1)).to be_empty
    expect(refused.errors).to be_of_kind(:depuis, :unreadable)
  end

  describe 'paging' do
    it 'clamps a page below the first' do
      expect(described_class.new(page: -3).page_within(4 * described_class::PER_PAGE)).to eq(1)
    end

    # Four pages, so the upper bound is distinguishable from the lower one.
    it 'clamps a page past the last' do
      expect(described_class.new(page: 999_999).page_within(4 * described_class::PER_PAGE)).to eq(4)
    end

    # PostgreSQL refuses an offset wider than a 64-bit integer, which is a 500
    # before the clamp.
    it 'clamps a page no database could offset to' do
      filter = submitted(page: '99999999999999999999999999')

      expect { filter.apply(AuditEvent.all, filter.page_within(1)).to_a }.not_to raise_error
    end
  end
end
