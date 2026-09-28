require 'rails_helper'

# Chapter 4.9 on France's side as a provider, played through the whole receiving
# path: `IncomingMessage::Process` opens and reopens the exchange, the answer
# chain chooses, the preview space decides, and the jobs answer later.
RSpec.describe 'The preview France offers as a provider' do
  include ActiveSupport::Testing::TimeHelpers
  include ActiveJob::TestHelper

  PREVIEW_CAPTURED_AT = '2026-08-11T09:22:22.000Z'.freeze
  RS = { 'rs' => 'urn:oasis:names:tc:ebxml-regrep:xsd:rs:4.0', **SlotReading::NAMESPACES }.freeze

  let(:submitted) { [] }
  let(:gateway) { instance_double(DomibusClient) }
  let(:first) { request_asking_preview }

  before do
    travel_to(Time.zone.parse(PREVIEW_CAPTURED_AT))
    allow(DomibusClient).to receive(:new).and_return(gateway)
    allow(gateway).to receive(:submit) do |envelope|
      submitted << envelope
      instance_double(SubmittedMessageParser, message_id: "soumis-#{submitted.size}")
    end
  end

  def deliver(message, id)
    allow(gateway).to receive(:retrieve).with(id).and_return(message)
    IncomingMessage::Process.call(message_id: id, uuid: Oots::SequentialUuids.new(prefix: "1a2b3c4d-#{id.delete('^0-9').rjust(4, '0')}-4000-8000"))
  end

  def body_of(envelope)
    Nokogiri::XML(Base64.decode64(Nokogiri::XML(envelope).at_xpath('//payload/value').text).force_encoding('UTF-8'))
  end

  def attachment_of(envelope) = Base64.decode64(Nokogiri::XML(envelope).xpath('//payload').last.at_xpath('value').text)

  def exception_of(document) = document.at_xpath('//rs:Exception', RS)

  def slot(document, name) = document.at_xpath("//rim:Slot[@name='#{name}']//rim:Value", RS)&.text

  def location = PreviewSession.sole.location

  def second(**) = second_request(location:, **)

  describe 'the first request' do
    before { deliver(first, 'm001') }

    # CA1: `rs:AuthorizationExceptionType`, `EDM:ERR:0002`, `PreviewRequired`.
    it 'is answered with the exception sending the user to the preview space' do
      exception = exception_of(body_of(submitted.sole))

      expect(exception.attributes.transform_values(&:value)).to include(
        'type' => 'rs:AuthorizationExceptionType', 'code' => 'EDM:ERR:0002', 'severity' => EdmException::PREVIEW_REQUIRED,
      )
      expect(slot(body_of(submitted.sole), 'PreviewLocation')).to eq(location)
    end

    # CA6, with a deployment in http as the suite runs: the address is under
    # `URL_OOTS_FRANCE`, carries a UUID v4 and nothing a return could collide with.
    it 'issues an address of this deployment, unpredictable and short' do
      expect(location).to match(%r{\A#{Settings.oots_france_url}/previsualisation/\h{8}-\h{4}-4\h{3}-[89ab]\h{3}-\h{12}\z})
      expect(location.size).to be <= 256
    end

    # RG18: not a failure — the exchange waits for its second request.
    it 'leaves the exchange waiting for the second request' do
      expect(Exchange.sole).to have_attributes(status: 'preview_required', preview_location: location)
    end

    # CA26: chapter 4.8 §3.2 asks for the address issued.
    it 'journals the address it issued with the exception' do
      expect(AuditEvent.find_by(event_type: 'error_sent')).to have_attributes(preview_location: location,
        edm_error_code: 'EDM:ERR:0002')
    end
  end

  # CA3 and CA4: the flag decides only where a document would go.
  describe 'what the flag does not change' do
    it 'serves a request whose flag is false' do
      deliver(request_asking_preview('false'), 'm001')

      expect(body_of(submitted.sole).root['status']).to end_with('Success')
      expect(PreviewSession.count).to eq(0)
    end

    def asking_preview_for(procedure)
      envelope_with_body('requete') do |body|
        body.dup.force_encoding(Encoding::UTF_8).sub(PreviewRequests::FLAG, '\\1true')
          .sub(/(<rim:Slot name="Procedure">.*?<rim:Value>)[^<]*/m, "\\1#{procedure}")
      end
    end

    it 'refuses an unknown procedure without preview' do
      deliver(asking_preview_for('ZZ'), 'm001')

      expect(exception_of(body_of(submitted.sole))['code']).to eq('EDM:ERR:0004')
      expect(PreviewSession.count).to eq(0)
    end

    it 'defers the procedure answered later without preview' do
      deliver(asking_preview_for(ProcedureCode::BIRTH_REGISTRATION), 'm001')

      expect(slot(body_of(submitted.sole), 'ResponseAvailableDateTime')).to be_present
      expect(PreviewSession.count).to eq(0)
    end

    # CA5: a flag nobody can read is not a flag set to false.
    it 'refuses a flag that is not a boolean, naming the schema' do
      deliver(request_asking_preview('peut-être'), 'm001')

      expect(exception_of(body_of(submitted.sole))).to have_attributes(
        attributes: include('code' => having_attributes(value: 'EDM:ERR:0003'),
          'detail' => having_attributes(value: PreviewConformance::BOOLEAN_SCHEMA)),
      )
    end
  end

  describe 'the second request, on the 2.0 line' do
    before { deliver(first, 'm001') }

    let(:second_id) { SecureRandom.uuid }
    let(:following) { second(exchange_id: first.exchange_id, request_id: second_id) }

    # CA15: no answer before the user decides, and the row stays open.
    it 'is answered nothing while the user has not decided' do
      deliver(following, 'm002')

      expect(submitted.size).to eq(1)
      expect(Exchange.sole).to have_attributes(status: 'pending', request_id: "urn:uuid:#{second_id}")
    end

    # CA15: T1 does not close it — T3 does.
    it 'is left alone by the expiry sweep of T1' do
      deliver(following, 'm002')

      travel(10.minutes) { expect(Exchange.expired).to be_empty }
    end

    # CA13 and CA16: decided after the request arrived, the answer goes by job.
    it 'carries the document the user saw once they accept' do
      deliver(following, 'm002')
      seen = PreviewSession.sole.document_bytes
      perform_enqueued_jobs { PreviewSession.sole.decide!(accepted: true) && AnswerPreviewedRequestJob.perform_later(PreviewSession.sole.id) }

      answer = body_of(submitted.last)
      expect(answer.root['status']).to end_with('Success')
      expect(answer.root['requestId']).to eq("urn:uuid:#{second_id}")
      expect(Digest::SHA256.hexdigest(attachment_of(submitted.last))).to eq(Digest::SHA256.hexdigest(seen))
      expect(Nokogiri::XML(submitted.last).to_s).to include(first.exchange_id)
      expect(Exchange.sole.status).to eq('delivered')
    end

    # The gateway refusing the late answer settles the exchange, as it would on
    # arrival, and lets the job record the failure.
    it 'settles the exchange in failure when the gateway refuses the late answer' do
      deliver(following, 'm002')
      allow(gateway).to receive(:submit).and_raise(Faraday::ConnectionFailed, 'refusé')
      PreviewSession.sole.decide!(accepted: true)

      expect { AnswerPreviewedRequestJob.perform_now(PreviewSession.sole.id) }.to raise_error(Faraday::ConnectionFailed)
      expect(Exchange.sole.status).to eq('failed')
      expect(PreviewSession.sole).to have_attributes(document: nil, second_request: nil)
    end

    # CA14: nothing accepted, an empty list and no attachment.
    it 'carries an empty list when the user decided first to use nothing' do
      PreviewSession.sole.decide!(accepted: false)
      deliver(following, 'm002')

      answer = body_of(submitted.last)
      expect(answer.root['status']).to end_with('Success')
      expect(answer.xpath('/*/rim:RegistryObjectList/*', RS)).to be_empty
      expect(Nokogiri::XML(submitted.last).xpath('//payload').size).to eq(1)
      expect(PreviewSession.sole).to have_attributes(status: 'answered', document: nil, decision: nil)
    end

    # CA9: what carries the subject goes with the answer.
    it 'erases what it kept once it has answered' do
      PreviewSession.sole.decide!(accepted: true)
      deliver(following, 'm002')

      expect(PreviewSession.sole).to have_attributes(status: 'answered', document: nil, first_request: nil)
    end

    # CA19: an address France did not issue, or under another exchange.
    it 'refuses an address France never issued, without echoing it' do
      deliver(second_request(location: 'https://oots.example/previsualisation/inconnue', exchange_id: first.exchange_id),
        'm002')

      refused = body_of(submitted.last)
      expect(exception_of(refused)['code']).to eq('EDM:ERR:0003')
      expect(exception_of(refused)['detail']).to eq(EvidenceProvision::PreviewAnswers::UNKNOWN_PREVIEW)
      expect(slot(refused, 'PreviewLocation')).to be_nil
    end

    it 'refuses the address under another exchange' do
      deliver(second(exchange_id: SecureRandom.uuid), 'm002')

      expect(exception_of(body_of(submitted.last))['detail']).to eq(EvidenceProvision::PreviewAnswers::UNKNOWN_PREVIEW)
    end

    it 'refuses an address already answered' do
      PreviewSession.sole.decide!(accepted: true)
      deliver(following, 'm002')
      deliver(second(exchange_id: first.exchange_id), 'm003')

      expect(exception_of(body_of(submitted.last))['code']).to eq('EDM:ERR:0003')
    end

    # CA24: past T2 with no second request, the timeout.
    it 'refuses a second request arriving past T2' do
      travel(17.minutes) { deliver(following, 'm002') }

      expect(exception_of(body_of(submitted.last))['code']).to eq('EDM:ERR:0005')
    end

    # The sweep answers the timeout before it destroys what is past T2 + T3,
    # so a request held to the very end is still answered.
    it 'answers the timeout even in the run that destroys the row' do
      deliver(following, 'm002')
      travel(57.minutes) { ExpirePreviewSessionsJob.perform_now }

      expect(exception_of(body_of(submitted.last))['code']).to eq('EDM:ERR:0005')
      expect(PreviewSession.count).to eq(0)
    end

    # CA25: past T3, the sweep answers the timeout and says the user left.
    it 'answers the timeout once T3 runs out on an undecided user' do
      deliver(following, 'm002')
      travel(41.minutes) { perform_enqueued_jobs { ExpirePreviewSessionsJob.perform_now } }

      expect(exception_of(body_of(submitted.last))['code']).to eq('EDM:ERR:0005')
      expect(AuditEvent.find_by(event_type: 'preview_decided').detail).to eq(AuditEvent::UNDECIDED)
      expect(PreviewSession.sole).to have_attributes(status: 'expired', second_request: nil)
    end
  end

  # CA2, CA21 and CA22.
  describe 'the 1.2 line' do
    let(:first) { request_asking_preview(line: :v1_2) }

    before { deliver(first, 'm001') }

    it 'asks for the preview with a PreviewMethod GET' do
      expect(slot(body_of(submitted.sole), 'PreviewMethod')).to eq('GET')
    end

    it 'recognises the second request by its address, and answers its own identifier' do
      second_id = SecureRandom.uuid
      PreviewSession.sole.decide!(accepted: true)
      deliver(second(line: :v1_2, request_id: second_id), 'm002')

      expect(body_of(submitted.last).root['requestId']).to eq("urn:uuid:#{second_id}")
      expect(Exchange.find_by(request_id: "urn:uuid:#{second_id}").status).to eq('delivered')
    end

    # Held first, decided later: the job recalls the request by its own
    # identifier, the 1.2 header naming no exchange.
    it 'answers the held request once the user decides later' do
      second_id = SecureRandom.uuid
      deliver(second(line: :v1_2, request_id: second_id), 'm002')
      perform_enqueued_jobs do
        EvidenceProvision::RecordPreviewDecision.call(preview_session: PreviewSession.sole, decision: 'accepted')
      end

      expect(body_of(submitted.last).root['requestId']).to eq("urn:uuid:#{second_id}")
      expect(Exchange.find_by(request_id: "urn:uuid:#{second_id}").status).to eq('delivered')
    end

    it 'refuses a ReturnLocation under R-EDM-REQ-S019' do
      deliver(second(line: :v1_2, slots: preview_slots(location, 'https://portail.example')), 'm002')

      expect(exception_of(body_of(submitted.last))['detail']).to eq('R-EDM-REQ-S019')
    end
  end
end
