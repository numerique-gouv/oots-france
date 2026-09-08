require 'rails_helper'

# The invariant that makes three types worth having: exactly one of a refusal,
# a document and a date, and that one present. A constructor alone cannot hold
# it — nothing stops a fourth caller — where a type can.
RSpec.describe 'Les trois réponses de la France' do
  let(:envelope) { instance_double(OutgoingEnvelopeBuilder, first_part: nil) }
  let(:exception) { EdmException::OBJECT_NOT_FOUND }
  let(:evidence) { Evidence.new(identifier: 'urn:evidence', part: nil) }
  let(:trail) { instance_double(AuditTrail, error_sent: nil, response_sent: nil) }
  let(:exchange) { create(:exchange, :sent) }

  # Two halves to the invariant, and each has its own guard: no type takes the
  # members of another, and none takes its own empty.
  it 'refuses to be built carrying an answer of another kind' do
    expect { Answers::Refusal.new(envelope:, identifier: 'a', exception:, evidence:) }.to raise_error(ArgumentError)
    expect { Answers::Served.new(envelope:, identifier: 'a', evidence:, available_at: 1.day.from_now) }
      .to raise_error(ArgumentError)
    expect { Answers::Deferral.new(envelope:, identifier: 'a', available_at: 1.day.from_now, exception:) }
      .to raise_error(ArgumentError)
  end

  # A served answer with no document, a deferral with no date and a refusal with
  # no exception are exactly the states these types exist to rule out — and what
  # would otherwise surface far downstream, as a `NoMethodError` on `nil.code`.
  it 'refuses to be built without the answer it is about' do
    expect { Answers::Refusal.new(envelope:, identifier: 'a', exception: nil) }.to raise_error(ArgumentError)
    expect { Answers::Served.new(envelope:, identifier: 'a', evidence: nil) }.to raise_error(ArgumentError)
    expect { Answers::Deferral.new(envelope:, identifier: 'a', available_at: nil) }.to raise_error(ArgumentError)
  end

  # Including `Answers::Answer` is what declares membership, so a fourth answer
  # that forgot `record` or `settle` would be caught here rather than by a
  # `NoMethodError` the first time that path ran.
  it 'donne aux trois la même surface' do
    answers = [Answers::Refusal.new(envelope:, identifier: 'a', exception:),
               Answers::Served.new(envelope:, identifier: 'a', evidence:),
               Answers::Deferral.new(envelope:, identifier: 'a', available_at: 1.day.from_now)]

    expect(answers).to all(be_a(Answers::Answer).and(respond_to(:record, :settle, :exception, :envelope, :identifier)))
  end

  # Only a refusal names one, and `answer_not_sent` records it whichever answer
  # the gateway would not take.
  it 'carries an exception on the refusal alone' do
    expect(Answers::Refusal.new(envelope:, identifier: 'a', exception:).exception).to eq(exception)
    expect(Answers::Served.new(envelope:, identifier: 'a', evidence:).exception).to be_nil
    expect(Answers::Deferral.new(envelope:, identifier: 'a', available_at: 1.day.from_now).exception).to be_nil
  end

  describe 'the line each writes in the log' do
    it 'records a refusal as an error sent, under the code the correspondent reads' do
      Answers::Refusal.new(envelope:, identifier: 'a', exception:).record(trail, message_id: 'm')

      expect(trail).to have_received(:error_sent).with(message_id: 'm', exception:)
    end

    it 'records a served answer as a response, with the evidence it carried' do
      Answers::Served.new(envelope:, identifier: 'a', evidence:).record(trail, message_id: 'm')

      expect(trail).to have_received(:response_sent).with(message_id: 'm', evidence:)
    end

    # Said rather than left open: a deferral is exactly the answer that carries
    # no document, and chapter 4.5.2 is why.
    it 'records a deferral as a response naming no evidence' do
      Answers::Deferral.new(envelope:, identifier: 'a', available_at: 1.day.from_now).record(trail, message_id: 'm')

      expect(trail).to have_received(:response_sent).with(message_id: 'm', evidence: nil)
    end
  end

  describe 'how each closes the exchange' do
    it 'fails it under the code and the wording the refusal carries' do
      Answers::Refusal.new(envelope:, identifier: 'a', exception:).settle(exchange)

      expect(exchange).to have_attributes(status: 'failed', edm_error_code: exception.code,
        error_description: exception.message)
    end

    it 'delivers it when the document went out' do
      Answers::Served.new(envelope:, identifier: 'a', evidence:).settle(exchange)

      expect(exchange.status).to eq('delivered')
    end

    # A settled state and not a waiting one: nothing further arrives on this
    # exchange, the portal coming back with a request of its own.
    it 'defers it on the date announced' do
      announced = Time.zone.parse('2026-09-01T08:00:00Z')

      Answers::Deferral.new(envelope:, identifier: 'a', available_at: announced).settle(exchange)

      expect(exchange).to have_attributes(status: 'deferred', response_available_at: announced)
    end
  end
end
