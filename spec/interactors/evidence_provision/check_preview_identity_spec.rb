require 'rails_helper'

# Chapter 4.9 §2, step 18, on the subject of the captured request: Sophie
# Dupont, born 1965-11-25, whom the request names without an eIDAS identifier.
RSpec.describe EvidenceProvision::CheckPreviewIdentity do
  include ActiveJob::TestHelper

  let(:session) { create(:preview_session) }

  def identity(**overrides)
    Demo::UserIdentity.new(given_name: 'Sophie', family_name: 'Dupont', birthdate: '1965-11-25',
      level_of_assurance: 'Substantial', subject: 'sub', id_token: 'jeton', france_connect: 'fake', **overrides)
  end

  def check(identification) = described_class.call(preview_session: session, identification:)

  def identified(**) = Interactor::Context.build(identity: identity(**))

  it 'confirms the person of the request' do
    expect(check(identified).verdict).to eq(:confirmed)
    expect(session.reload).to have_attributes(status: 'pending', identification: nil)
  end

  # The identifier is compared only where both sides carry one.
  it 'compares no eIDAS identifier the request does not carry' do
    expect(check(identified(eidas_identifier: 'DK/FR/61f6a1b0-3d3c-4f24')).verdict).to eq(:confirmed)
  end

  it 'refuses another given name, and journals the outcome alone' do
    expect(check(identified(given_name: 'Sophia')).verdict).to eq(:refused)
    expect(session.reload.identification).to eq(PreviewSession::MISMATCHED)

    event = AuditEvent.find_by!(event_type: 'preview_identified')
    expect(event.detail).to eq(PreviewSession::MISMATCHED)
    expect([event.evidence_subject, event.attributes.values.join]).to all(satisfy { |text| text.to_s.exclude?('Sophia') })
  end

  # On 2.0 the way back is the portal's, from the second request: the browser
  # whose failure concludes the address is sent back by it, whichever came
  # first.
  it 'refuses with the way back on 2.0 when the second request came first' do
    session.hold!(raw: '<second/>', sent_at: Time.current, message_id: 'second', answering: nil,
      return_location: 'https://portail.example/retour')

    expect(check(identified(given_name: 'Sophia')).verdict).to eq(:refused)
  end

  it 'refuses an identification that did not complete' do
    failure = Interactor::Context.build
    expect { failure.fail! }.to raise_error(Interactor::Failure)

    expect(check(failure).verdict).to eq(:refused)
    expect(session.reload.identification).to eq(PreviewSession::UNAUTHENTICATED)
  end

  # Once answered, the subject is gone: nothing is checked, nor journalled.
  it 'gives no verdict once the subject is erased' do
    session.update!(first_request: nil, status: 'answered')

    expect(check(identified).verdict).to be_nil
    expect(AuditEvent.where(event_type: 'preview_identified')).to be_empty
  end
end
