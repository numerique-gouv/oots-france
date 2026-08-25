require 'rails_helper'

RSpec.describe PurgeAuditEventsJob do
  include ActiveSupport::Testing::TimeHelpers

  # Article 17(4) sets twelve months, and sets them as a term as much as a duty:
  # past it, the log holds personal data nobody is entitled to keep.
  # The body lives on the row rather than in a table of its own, so the purge
  # takes it without having to know about it: what article 17 gives a term to
  # includes the message as it circulated.
  it 'erases what is older than the retention, and only that' do
    old = create(:audit_event, :with_regrep_body, occurred_at: 13.months.ago)
    recent = create(:audit_event, occurred_at: 11.months.ago)

    described_class.perform_now

    expect(AuditEvent.where(id: old.id)).to be_empty
    expect(AuditEvent.where(id: recent.id)).to contain_exactly(recent)
  end

  # Exactly on the cutoff, the record stays: twelve months is a floor, and a
  # range that swallowed its own boundary would put the deployment under it.
  it 'keeps what sits exactly on the cutoff' do
    freeze_time do
      borderline = create(:audit_event, occurred_at: Settings.audit_trail_retention.ago)

      described_class.perform_now

      expect(AuditEvent.where(id: borderline.id)).to contain_exactly(borderline)
    end
  end
end
