require 'rails_helper'

RSpec.describe EventTypeComponent, type: :component do
  # The badge degrades on a type it does not know rather than raising: a page
  # that reads a regulatory trace has to render what the trace holds. This test
  # is what keeps the degradation from becoming the normal case — the day a
  # ninth event type is written, it is here that it comes up short.
  it 'gives every event type a badge' do
    expect(described_class::BADGES.keys).to match_array(AuditEvent::EVENT_TYPES)
  end

  it 'gives every event type a French label' do
    missing = AuditEvent::EVENT_TYPES.reject { |type| I18n.exists?("admin.journal.event_types.#{type}") }

    expect(missing).to be_empty
  end

  it 'renders the label of the type it is given' do
    render_inline(described_class.new(event_type: 'error_received'))

    expect(page).to have_text(I18n.t('admin.journal.event_types.error_received'))
  end
end
