require 'rails_helper'

RSpec.describe PreviewSession do
  include ActiveSupport::Testing::TimeHelpers

  let!(:session) { create(:preview_session) }
  let(:message) { instance_double(RetrievedMessageParser, raw: '<second/>', sent_at: Time.current) }

  def hold(held = session, id: 'second-message')
    held.hold!(raw: message.raw, sent_at: message.sent_at, message_id: id, answering: nil, return_location: 'https://portail.example/retour')
  end

  # CA9 of OOTS-72: read back only through the model, as `audit_events.evidence_subject`.
  it 'keeps what carries the subject encrypted at rest' do
    stored = described_class.connection.select_one("SELECT document, first_request FROM preview_sessions WHERE id = #{session.id}")

    expect(stored.values).to all(satisfy { |value| value.start_with?('{"p":') })
    expect(session.reload.document_bytes).to eq('%PDF-1.4 justificatif vu')
  end

  describe 'the first visit' do
    it 'opens within T2' do
      travel(15.minutes) { expect(session).to be_openable }
    end

    # RG8: « une première visite plus tardive » falls on a link no longer valid.
    it 'does not open past T2' do
      travel(17.minutes) { expect(session).not_to be_openable }
    end

    # RG9: a user who opened the space may come back while the link lives.
    it 'reopens past T2 once visited, while a second request keeps the link alive' do
      session.visited!
      hold

      travel(17.minutes) { expect(session.reload).to be_openable }
    end
  end

  describe 'the decision and the second request, in either order' do
    it 'holds the request without a decision, which then asks for an answer' do
      expect(hold).to be_nil
      expect(session.decide!(accepted: true)).to be(true)
    end

    it 'keeps a decision made first, which the request then reads' do
      expect(session.decide!(accepted: false)).to be(false)
      expect(hold).to eq(PreviewSession::REFUSED)
    end

    # RG9: the choice made, the link no longer restarts the interaction.
    it 'refuses a second decision' do
      session.decide!(accepted: true)

      expect(session.decide!(accepted: false)).to be_nil
      expect(session.reload.decision).to eq(PreviewSession::ACCEPTED)
    end
  end

  # Chapter 4.9 §2, step 14: once the link has run out, no choice reaches it.
  it 'refuses a decision past T2' do
    travel(17.minutes) { expect(session.decide!(accepted: true)).to be_nil }

    expect(session.reload.decision).to be_nil
  end

  describe 'expiry' do
    it 'expires at T2 without a second request' do
      travel(17.minutes) { expect(session).to be_expired }
    end

    it 'expires at T3 after the second request, the user undecided' do
      hold
      travel(41.minutes) { expect(session.reload).to be_expired }
    end

    it 'does not expire once decided, the answer being due' do
      hold
      session.decide!(accepted: true)

      travel(41.minutes) { expect(session.reload).not_to be_expired }
    end

    # CA23: T2 and T3 apply whether or not the timeout dispositif does.
    it 'applies with the timeout dispositif off' do
      stub_const('ENV', ENV.to_h.merge(Settings::TIMEOUT_SWITCH => 'false'))

      travel(17.minutes) { expect(session).to be_expired }
    end

    it 'keeps only what answering the second request still needs' do
      hold
      travel(41.minutes) { session.expire! }

      expect(session.reload).to have_attributes(document: nil, first_request: nil, decision: nil,
        second_message_id: 'second-message')
    end
  end

  # CA9: the subject goes as the answer does; the address stays until T2 + T3.
  it 'erases the subject once concluded' do
    session.decide!(accepted: true)
    session.conclude!

    expect(session.reload).to have_attributes(status: 'answered', **PreviewSession::SUBJECT.index_with(nil))
    expect(described_class.past_retention).to be_empty
    travel(57.minutes) { expect(described_class.past_retention).to eq([session]) }
  end

  describe 'the second request it is continued by' do
    it 'is one under the same ExchangeId, on the 2.0 line' do
      expect(session.continued_by?(session.exchange_id)).to be(true)
      expect(session.continued_by?('autre')).to be(false)
    end

    it 'is any on the 1.2 line, the address alone tying the two' do
      earlier = create(:preview_session, :legacy_line)

      expect(earlier.continued_by?(nil)).to be(true)
    end

    it 'is none once answered' do
      session.conclude!

      expect(session.continued_by?(session.exchange_id)).to be(false)
    end
  end
end
