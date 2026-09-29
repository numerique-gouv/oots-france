require 'rails_helper'

RSpec.describe ExpirePreviewSessionsJob do
  include ActiveSupport::Testing::TimeHelpers
  include ActiveJob::TestHelper

  let!(:session) { create(:preview_session) }

  # RG29 of OOTS-72: T2 without a second request — the subject goes, the user
  # is said to have left without deciding, and nothing is answered.
  it 'expires a link nobody followed up at T2, and journals the user left undecided' do
    travel(17.minutes) do
      expect { described_class.perform_now }.not_to have_enqueued_job(AnswerPreviewedRequestJob)
    end

    expect(session.reload).to have_attributes(status: 'expired', document: nil, first_request: nil)
    expect(AuditEvent.sole).to have_attributes(event_type: 'preview_decided', detail: AuditEvent::UNDECIDED)
  end

  it 'journals no departure for a user who had decided' do
    session.decide!(accepted: true)
    travel(17.minutes) { described_class.perform_now }

    expect(session.reload.status).to eq('expired')
    expect(AuditEvent.count).to eq(0)
  end

  # One row may not carry away the others, as in `ExpireExchangesJob`.
  it 'expires the sessions behind one that fails' do
    broken = create(:preview_session, id: session.id - 1)
    allow(EvidenceProvision::ExpirePreview).to receive(:call).and_call_original
    allow(EvidenceProvision::ExpirePreview).to receive(:call).with(preview_session: broken).and_raise(ArgumentError)

    travel(17.minutes) { described_class.perform_now }

    expect(session.reload.status).to eq('expired')
  end

  it 'leaves alone a link still within T2' do
    travel(15.minutes) { described_class.perform_now }

    expect(session.reload).to have_attributes(status: 'pending', document: be_present)
  end

  # RG11: past T2 + T3, the address is one France never issued.
  it 'destroys the row at T2 + T3' do
    travel(57.minutes) { described_class.perform_now }

    expect(PreviewSession.count).to eq(0)
  end
end
