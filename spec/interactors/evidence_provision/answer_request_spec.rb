require 'rails_helper'

# The inbound side: another member state asks France for evidence. Nothing here
# was covered before — the only path ever exercised was the happy one, and only
# by the end-to-end scenarios, which need a live gateway.
RSpec.describe EvidenceProvision::AnswerRequest do
  include ActiveSupport::Testing::TimeHelpers

  subject(:answer) { described_class.call(message:, gateway:, uuid: Oots::SequentialUuids.new, audit_trail: AuditTrail.new) }

  let(:gateway) { gateway_accepting_submissions }
  let(:message) { RetrievedMessageParser.new(real_envelope('requete')) }

  # The instant the fixtures of `incoming/reel/` were captured on a real gateway.
  # Their ebMS timestamp ages with the calendar, so every request of this file
  # would turn into a timeout of chapter 4.4 as the days pass; pinning the clock
  # there keeps them inside the interval. Named rather than read off `message`,
  # which one group deliberately makes unreadable.
  CAPTURED_AT = '2026-08-11T09:22:22.000Z'.freeze

  before { travel_to(Time.zone.parse(CAPTURED_AT)) }

  def submitted = gateway_body.then { |body| Nokogiri::XML(decoded_payload(body)) }

  it 'serves the evidence for the system-check procedure' do
    answer

    expect(submitted.root.name).to eq('QueryResponse')
    expect(status_of(submitted)).to end_with('Success')
  end

  # Chapter 4.8 puts the evidence response identifier and the fingerprint of the
  # evidence among what a provider must log.
  it 'journals what France answered' do
    answer

    expect(AuditEvent.last).to have_attributes(
      event_type: 'response_sent',
      conversation_id: message.conversation_id,
      message_id: 'message-passerelle',
      exchange_id: message.exchange_id,
      request_id: message.body.request_id,
      edm_error_code: nil,
      evidence_digest: Digest::SHA256.hexdigest(Rails.root.join(described_class::EVIDENCE_PATH).binread),
      # The identifier of France's own answer: chapter 4.8 walks the
      # non-repudiation chain from it, and it is what `Answer` carries.
      response_id: identifier_of(submitted),
      # And the identifier of the document that answer carried, which the same
      # chapter asks the data service for as much as the requester. Read back
      # from the message the gateway was handed, so nothing but the value that
      # circulated can satisfy it.
      evidence_identifier: evidence_identifier_of(submitted),
      # « For evidence content referenced using `rim:RepositoryItemRef`
      # elements, MIME type and MIME content identifier », starred for the data
      # service too. Read back from the reference the submitted body makes of
      # the attachment, so a second `cid:` minted beside it would not pass.
      evidence_mime_type: Attachment::MIME_TYPE,
      evidence_content_id: repository_item_ref_of(submitted),
      # Where France answers, the country logged is the one the request named:
      # `R-EDM-REQ-C073` puts it on the agent classified `ER`, and France's own
      # response carries no address for that agent.
      country_code: 'FR',
    )
  end

  # Chapter 4.8 asks the response flow for « MIME type and full content of first
  # MIME part » too, in the second of its two tables. Read against
  # what the gateway was handed, so no second rendering can stand in for it.
  it 'journals the very first MIME part it submitted' do
    answer

    expect(AuditEvent.last).to have_attributes(
      regrep_mime_type: 'application/x-ebrs+xml',
      regrep_body: decoded_payload(gateway_body),
    )
  end

  it 'attaches the document France holds' do
    answer

    payloads = Nokogiri::XML(gateway_body).xpath('//payload')

    expect(payloads.size).to eq(2)
    expect(Base64.decode64(payloads.last.at_xpath('value').text)).to start_with('%PDF')
  end

  # Any procedure other than the system check: France has no provider connected,
  # and says so with the code the TDD prescribe rather than staying silent.
  describe 'a procedure it does not serve' do
    let(:message) { RetrievedMessageParser.new(real_envelope('requete.demarcheInconnue')) }

    it 'answers EDM:ERR:0004' do
      answer

      expect(code_of(submitted)).to eq('EDM:ERR:0004')
    end

    it 'journals the refusal under the code it answered with' do
      answer

      expect(AuditEvent.last).to have_attributes(event_type: 'error_sent', edm_error_code: 'EDM:ERR:0004',
        country_code: 'FR', evidence_identifier: nil)
    end

    it 'keeps the rs:Exception it sent, as it sent it' do
      answer

      expect(AuditEvent.last.regrep_body).to eq(decoded_payload(gateway_body))
      expect(AuditEvent.last.regrep_body).to include('rs:Exception')
    end
  end

  # Chapter 4.5.2: France holds no document it merely has to wait for, so one
  # procedure is designated to answer the announcement — stub 10. What matters
  # is that the message exists and is confronted with the response rules.
  describe 'the procedure it answers with a deferral' do
    let(:message) { request_for(ProcedureCode::BIRTH_REGISTRATION) }

    it 'answers a response whose status announces the evidence for later' do
      answer

      expect(submitted.root.name).to eq('QueryResponse')
      expect(status_of(submitted)).to end_with('Unavailable')
    end

    # `R-EDM-RESP-S045`: the slot a deferral must carry, and that
    # `R-EDM-RESP-S014` forbids to any other status.
    it 'names the date the evidence will be available' do
      answer

      expect(available_at_of(submitted))
        .to eq((Time.current + DeferredResponseBuilder::DEFERRAL).utc.iso8601(3))
    end

    it 'attaches no document, having none to attach' do
      answer

      expect(Nokogiri::XML(gateway_body).xpath('//payload').size).to eq(1)
    end

    # A response did go out, and it carried nothing: the journal says both.
    it 'journals a response sent, with no fingerprint' do
      answer

      expect(AuditEvent.last).to have_attributes(
        event_type: 'response_sent', edm_error_code: nil, evidence_digest: nil,
        evidence_mime_type: nil, evidence_content_id: nil, evidence_identifier: nil,
        response_id: identifier_of(submitted),
      )
    end

    it 'settles the exchange France opened as deferred, carrying the date' do
      create(:exchange, incoming: true, exchange_id: message.exchange_id, country_code: nil)

      answer

      expect(Exchange.sole).to have_attributes(
        status: 'deferred',
        response_available_at: Time.current + DeferredResponseBuilder::DEFERRAL,
      )
    end

    # The guard on the distribution format sits above the deferral, and this is
    # the only example that reads it on a procedure other than the system check.
    it 'refuses a format it does not serve before announcing anything' do
      allow(message.body).to receive(:evidence_type)
        .and_return(EvidenceType.new(id: 'x', descriptions: {}, distribution_format: 'application/xml'))

      answer

      expect(code_of(submitted)).to eq('EDM:ERR:0007')
    end

    # Chapter 4.4 wants an exceeded interval answered « instead of a successful
    # response »: a correspondent that has given up has no use for a date.
    it 'answers the timeout instead once the request is past its interval' do
      travel_to(Time.zone.parse(CAPTURED_AT) + Settings.provider_timeout + 1.second)

      answer

      expect(code_of(submitted)).to eq('EDM:ERR:0005')
    end
  end

  # An unsupported optional capability, not an invalid request: the correspondent
  # asked for a distribution format we do not serve.
  describe 'a distribution format it does not serve' do
    let(:message) { envelope_with_body('requete') { |body| body.sub('application/pdf', 'application/xml') } }

    it 'answers EDM:ERR:0007' do
      answer

      expect(code_of(submitted)).to eq('EDM:ERR:0007')
    end

    it 'journals the refusal under the code it answered with' do
      answer

      expect(AuditEvent.last).to have_attributes(event_type: 'error_sent', edm_error_code: 'EDM:ERR:0007')
    end
  end

  describe 'a request it cannot read past the requester' do
    let(:message) do
      envelope_with_body('requete') { |body| body.sub(%r{<rim:Slot name="Procedure">.*?</rim:Slot>}m, '') }
    end

    # Readable enough to answer, not enough to serve. Silence would teach the
    # correspondent nothing.
    it 'answers EDM:ERR:0003 rather than nothing at all' do
      answer

      expect(code_of(submitted)).to eq('EDM:ERR:0003')
    end

    it 'journals the refusal under the code it answered with' do
      answer

      expect(AuditEvent.last).to have_attributes(event_type: 'error_sent', edm_error_code: 'EDM:ERR:0003')
    end

    # A slot the reader could not find is not a rule with a number: the answer
    # degrades to the bare code rather than inventing an identifier for it.
    it 'writes no detail when no rule names the failure' do
      answer

      expect(detail_of(submitted)).to be_nil
    end
  end

  # Chapter 4.6 through and through: a request that is well formed and still not
  # one France may answer. What the correspondent gets back names the rule.
  describe 'a request that breaks a business rule' do
    let(:message) do
      envelope_with_body('requete') { |body| body.sub(%r{<rim:Slot name="PossibilityForPreview">.*?</rim:Slot>}m, '') }
    end

    it 'answers EDM:ERR:0003 naming the rule it applied' do
      answer

      expect(code_of(submitted)).to eq('EDM:ERR:0003')
      expect(detail_of(submitted)).to eq('R-EDM-REQ-S009')
    end

    # Article 17 asks for the errors as much as the exchanges, and a refusal
    # whose reason is not recorded cannot be answered for afterwards.
    it 'journals the rule alongside the code' do
      answer

      expect(AuditEvent.last).to have_attributes(event_type: 'error_sent', edm_error_code: 'EDM:ERR:0003',
        detail: 'R-EDM-REQ-S009')
    end
  end

  # `R-EDM-REQ-S004` (FATAL) on the request, `R-EDM-ERR-S004` on the answer, and
  # `R-EDM-ERR-C025` (FATAL) between the two: the one response that may omit
  # `requestId` is an `rs:InvalidRequestExceptionType`, which is exactly what
  # France answers here. Recopying the malformed identifier would have France
  # sign a response breaking a fatal rule; inventing one would answer a request
  # nobody made.
  describe 'a request whose own identifier is not a UUID' do
    let(:message) do
      envelope_with_body('requete') { |body| body.sub(/id="urn:uuid:[^"]*"/, 'id="pas-un-uuid"') }
    end

    it 'answers EDM:ERR:0003 naming the rule the identifier broke' do
      answer

      expect(code_of(submitted)).to eq('EDM:ERR:0003')
      expect(detail_of(submitted)).to eq('R-EDM-REQ-S004')
    end

    it 'omits requestId rather than echoing what it refused' do
      answer

      expect(submitted.root.attribute('requestId')).to be_nil
    end

    it 'settles the exchange in failure, as any other refusal does' do
      create(:exchange, incoming: true, exchange_id: message.exchange_id, country_code: nil)

      answer

      expect(Exchange.sole).to have_attributes(status: 'failed', edm_error_code: 'EDM:ERR:0003')
    end

    # The journal keeps what it could read: an identifier it could not read is
    # left empty rather than recorded malformed, and the refusal is recorded
    # all the same.
    it 'journals the refusal with no request identifier' do
      answer

      expect(AuditEvent.last).to have_attributes(event_type: 'error_sent', edm_error_code: 'EDM:ERR:0003',
        detail: 'R-EDM-REQ-S004', request_id: nil)
    end
  end

  # Chapter 4.4: « A Data Service MUST reject requests that use identifiers that
  # were used in previously processed requests. »
  describe 'a request whose identifier has already been answered' do
    subject(:answer) do
      described_class.call(message:, gateway:, message_id: 'message-en-cours',
        uuid: Oots::SequentialUuids.new, audit_trail: AuditTrail.new)
    end

    before do
      create(:audit_event, event_type: 'request_received', request_id: message.body.request_id,
        message_id: 'message-precedent')
    end

    it 'refuses it rather than serving the evidence twice' do
      answer

      expect(code_of(submitted)).to eq('EDM:ERR:0003')
      expect(detail_of(submitted)).to eq(described_class::REPLAYED_IDENTIFIER)
    end

    # `IncomingMessage::Process` journals an arrival before it dispatches, so
    # the request being answered has a line of its own here. Counting it would
    # make every request its own replay.
    context 'when the only line is the arrival of this very message' do
      before do
        AuditEvent.delete_all
        create(:audit_event, event_type: 'request_received', request_id: message.body.request_id,
          message_id: 'message-en-cours')
      end

      it 'serves the evidence' do
        answer

        expect(status_of(submitted)).to end_with('Success')
      end
    end
  end

  # Chapter 4.4: a Data Service implementing timeout « shall return a timeout
  # exception response … instead of a successful response when the process of
  # processing the request exceeds a configured timeout value ».
  describe 'a request older than the interval France gives itself' do
    before { travel_to(message.sent_at + Settings.provider_timeout + 1.second) }

    it 'answers the timeout exception rather than the evidence' do
      answer

      expect(code_of(submitted)).to eq('EDM:ERR:0005')
    end

    it 'settles the exchange France opened under that code' do
      exchange = create(:exchange, incoming: true, exchange_id: message.exchange_id,
        country_code: nil, procedure_code: nil, evidence_requester_id: nil)

      answer

      expect(exchange.reload).to have_attributes(status: 'failed', edm_error_code: 'EDM:ERR:0005')
    end

    it 'journals the error it sent' do
      answer

      expect(AuditEvent.last).to have_attributes(event_type: 'error_sent', edm_error_code: 'EDM:ERR:0005')
    end

    # « instead of a successful response », and not instead of any response: the
    # two refusals above the guard keep their code however late the request.
    context 'when the procedure is one France does not serve' do
      let(:message) { RetrievedMessageParser.new(real_envelope('requete.demarcheInconnue')) }

      it 'refuses it as unknown rather than as expired' do
        answer

        expect(code_of(submitted)).to eq('EDM:ERR:0004')
      end
    end

    context 'when the distribution format is one France does not serve' do
      let(:message) { envelope_with_body('requete') { |body| body.sub('application/pdf', 'application/xml') } }

      it 'refuses it as unsupported rather than as expired' do
        answer

        expect(code_of(submitted)).to eq('EDM:ERR:0007')
      end
    end
  end

  # The one departure that would otherwise vanish whole. `Exchange` does record
  # the failure, but it carries no message, and the gateway never took the
  # answer: nothing else holds the document France had built.
  describe 'a gateway that will not take the answer' do
    let(:gateway) { instance_double(DomibusClient) }

    before { allow(gateway).to receive(:submit).and_raise(Faraday::ConnectionFailed, 'connexion refusée') }

    it 'journals the attempt, and still lets the failure surface' do
      expect { answer }.to raise_error(Faraday::ConnectionFailed)

      expect(AuditEvent.sole).to have_attributes(
        event_type: 'answer_not_sent',
        ebms_action: EbmsAction::EXECUTE_QUERY_RESPONSE,
        conversation_id: message.conversation_id,
        exchange_id: message.exchange_id,
        request_id: message.body.request_id,
        country_code: 'FR',
        edm_error_code: nil,
        detail: 'connexion refusée',
        # The gateway never named the message, there being none: a line
        # carrying one would send an auditor to a *Message Log* that has
        # nothing under it.
        message_id: nil,
      )
    end

    # The whole reason the line exists, asserted against what the gateway was
    # handed rather than against a second rendering of the same builder.
    it 'keeps the body of the answer that never went out' do
      expect { answer }.to raise_error(Faraday::ConnectionFailed)

      expect(AuditEvent.sole).to have_attributes(
        regrep_mime_type: EbmsHeaderBuilder::REGREP_MIME_TYPE,
        regrep_body: decoded_payload(gateway_body),
      )
    end

    context 'when what France was answering was a refusal' do
      let(:message) { RetrievedMessageParser.new(real_envelope('requete.demarcheInconnue')) }

      it 'journals the code the refusal carried, under the action of an exception' do
        expect { answer }.to raise_error(Faraday::ConnectionFailed)

        expect(AuditEvent.sole).to have_attributes(
          event_type: 'answer_not_sent', ebms_action: EbmsAction::EXCEPTION_RESPONSE,
          edm_error_code: 'EDM:ERR:0004',
        )
      end
    end

    # The gateway answering 200 with a body we cannot read is the same problem
    # from here: the answer is no more submitted than if the connection had
    # dropped.
    context 'when the gateway answers something we cannot read' do
      before { allow(gateway).to receive(:submit).and_raise(UnreadableMessageError, 'réponse du greffon illisible') }

      it 'journals the attempt all the same' do
        expect { answer }.to raise_error(UnreadableMessageError)

        expect(AuditEvent.sole).to have_attributes(
          event_type: 'answer_not_sent', detail: 'réponse du greffon illisible',
        )
      end
    end
  end

  # The boundary `submit` documents, and which nothing else holds: a body that
  # could not be built is not the gateway turning our answer away, and a line
  # saying it was would send an auditor looking at a gateway that was never
  # asked.
  describe 'an envelope that cannot be rendered at all' do
    before do
      envelope = instance_double(OutgoingEnvelopeBuilder)
      allow(envelope).to receive(:render).and_raise(UnreadableMessageError, 'enveloppe irrendue')
      allow(OutgoingEnvelopeBuilder).to receive(:new).and_return(envelope)
    end

    it 'journals nothing, the gateway never having been asked' do
      expect { answer }.to raise_error(UnreadableMessageError)

      expect(AuditEvent.count).to eq(0)
      expect(gateway).not_to have_received(:submit)
    end
  end

  # The failure of the submission, and not of the answer as a whole: an answer
  # the gateway took has its own line, and a second one would have an auditor
  # count one answer twice.
  it 'writes no line for an answer the gateway did take' do
    answer

    expect(AuditEvent.where(event_type: 'answer_not_sent')).to be_empty
  end

  # Counting the interval is the first thing the provider side asks of an
  # arriving message, and the answer can be unreadable. It reaches the same net
  # as any other unreadable field, rather than escaping as an exception nobody
  # answers.
  describe 'a request whose timestamp cannot be read' do
    let(:message) do
      document = Nokogiri::XML(real_envelope('requete'))
      document.xpath('//*[local-name()="Timestamp"]').first.content = ''

      RetrievedMessageParser.new(document.to_xml)
    end

    it 'answers EDM:ERR:0003 rather than raising' do
      answer

      expect(code_of(submitted)).to eq('EDM:ERR:0003')
    end
  end

  # A strict inequality: the instant the interval runs out is still inside it.
  describe 'a request sitting exactly on the interval France gives itself' do
    before { travel_to(message.sent_at + Settings.provider_timeout) }

    it 'still serves the evidence' do
      answer

      expect(status_of(submitted)).to end_with('Success')
    end
  end

  # The version travels twice, and no rule says the two must agree: each is
  # pinned to the same literal on its own — R-EDM-ebMS-038 for the header
  # property, R-EDM-REQ-C001 for the body slot — so they agree by transitivity,
  # and a header saying otherwise is a message no reading can reconcile.
  describe 'a request whose header contradicts its body on the version' do
    let(:message) do
      RetrievedMessageParser.new(real_envelope('requete').sub(EdmSpecification::IDENTIFIER, 'oots-edm:v1.0'))
    end

    it 'answers EDM:ERR:0003 naming the ebMS rule' do
      answer

      expect(code_of(submitted)).to eq('EDM:ERR:0003')
      expect(detail_of(submitted)).to eq('R-EDM-ebMS-038')
    end
  end

  # R-EDM-ebMS-019 makes the property mandatory, where -038 fixes its value: two
  # rules, two details on the wire, and a correspondent who omitted the property
  # is not one who declared the wrong version.
  describe 'a request whose header omits the version altogether' do
    # Removed as a node and not by a substitution: the prefix a gateway binds to
    # the ebMS namespace is its own, so only an XPath bound by URI finds the
    # property — and `remove` raises if it ever stops being there, where a regex
    # that matched nothing would leave the test passing on an intact envelope.
    let(:message) do
      envelope = Nokogiri::XML(real_envelope('requete'))
      envelope.at_xpath("//eb:Property[@name='SpecificationId']", OotsNamespaces::NAMESPACES).remove

      RetrievedMessageParser.new(envelope.to_xml)
    end

    it 'answers EDM:ERR:0003 naming the rule that requires the property' do
      answer

      expect(code_of(submitted)).to eq('EDM:ERR:0003')
      expect(detail_of(submitted)).to eq('R-EDM-ebMS-019')
    end
  end

  # `R-EDM-ebMS-017` and `-037` are both FATAL, and both are asked of the
  # document rather than of a party: they bind whoever emits. France answering
  # under an identifier a correspondent malformed breaks them on France's side,
  # the answer reusing what the request carried — and nothing conformant can say
  # so back, chapter 4.4 having every message of one exchange reuse its
  # `ExchangeId`. So the refusal is silent, and the journal holds it alone.
  describe 'a request whose ebMS identifiers are not UUIDs' do
    # What `IncomingMessage::Process` has already done by the time a handler
    # runs: the arrival is journalled and the exchange is open, malformed
    # identifier and all — an exchange a correspondent malformed must stay
    # recorded.
    let(:opened) do
      create(:exchange, incoming: true, exchange_id: message.exchange_id,
        conversation_id: message.conversation_id, procedure_code: '00', country_code: 'FI')
    end

    before { opened }

    context "when it is the exchange's" do
      let(:message) { request_with(:exchange_id, 'pas-un-uuid') }

      it 'submits nothing to the gateway' do
        expect { answer }.to raise_error(UnreadableMessageError, /pas-un-uuid/)
        expect(gateway).not_to have_received(:submit)
      end

      # The malformed value in its own column, and the fields read off the
      # exchange rather than off the request: `refuse_malformed` runs before the
      # body is touched, so the row it writes can only come from the one
      # `OpenExchange` opened.
      it 'journals the refusal, naming the rule it broke' do
        expect { answer }.to raise_error(UnreadableMessageError)

        expect(AuditEvent.last).to have_attributes(
          event_type: 'request_refused',
          exchange_id: 'pas-un-uuid',
          conversation_id: message.conversation_id,
          procedure_code: '00',
          country_code: 'FI',
          evidence_requester_id: opened.evidence_requester_id,
          detail: include('R-EDM-ebMS-037'),
        )
      end
    end

    context "when it is the conversation's" do
      let(:message) { request_with(:conversation_id, 'ni-celui-ci') }

      it 'submits nothing to the gateway' do
        expect { answer }.to raise_error(UnreadableMessageError, /ni-celui-ci/)
        expect(gateway).not_to have_received(:submit)
      end

      it 'journals the refusal, naming the rule it broke' do
        expect { answer }.to raise_error(UnreadableMessageError)

        expect(AuditEvent.last).to have_attributes(
          event_type: 'request_refused',
          exchange_id: message.exchange_id,
          conversation_id: 'ni-celui-ci',
          detail: include('R-EDM-ebMS-017'),
        )
      end
    end

    # One refusal and not two: the first identifier the header presents settles
    # it, which is also the lower of the two rule numbers. Pinned rather than
    # left open, so that a reader of the journal knows which of the two a line
    # names when both were wrong.
    context 'when both are malformed' do
      let(:message) do
        document = Nokogiri::XML(real_envelope('requete'))
        replace(document, IDENTIFIER_PATHS[:conversation_id], 'ni-lui')
        replace(document, IDENTIFIER_PATHS[:exchange_id], 'ni-lautre')

        RetrievedMessageParser.new(document.to_xml)
      end

      it 'refuses once, on the conversation identifier' do
        expect { answer }.to raise_error(UnreadableMessageError)

        expect(AuditEvent.where(event_type: 'request_refused').pluck(:detail))
          .to contain_exactly(include('R-EDM-ebMS-017'))
      end
    end

    # Values close enough to a UUID to pass a lax reading of the rule: a group one
    # digit short, a digit that is not hexadecimal, and a valid one preceded by
    # a line of its own.
    #
    # The third pins the anchors of `Exchange::UUID`. Ruby's `^`/`$` match at line
    # boundaries and not at the ends of the string, so a pattern written that way
    # accepts this value — and trimming cannot help, the break being inside it
    # where neither `strip` nor `normalize-space` reaches. The refusal here reads
    # the constant through `match?`, which nothing guards; only its use in
    # `validates` is, Rails rejecting a multiline-anchored pattern outright.
    %W[1647038b-7eaf-4711-b738-d5d83f96fa7 1647038b-7eaf-4711-b738-d5d83f96fazb
       pas-un-uuid\n1647038b-7eaf-4711-b738-d5d83f96fa7b].each do |near_miss|
      context "when it only looks like a UUID (#{near_miss.inspect})" do
        let(:message) { request_with(:exchange_id, near_miss) }

        it 'refuses it too' do
          expect { answer }.to raise_error(UnreadableMessageError)
          expect(gateway).not_to have_received(:submit)
        end
      end
    end

    # No exchange at all to hang the refusal on. `IncomingMessage::Process` opens
    # one before dispatching, so this does not arise today — but nothing in the
    # code compels it, exactly as `unknown_exchange` says of the settling path.
    # What the journal must never lose is the refused value itself, and the
    # reason carries it whether or not a row does.
    context 'when no exchange was opened at all' do
      let(:message) { request_with(:exchange_id, 'pas-un-uuid') }
      let(:opened) { nil }

      it 'still journals the refusal, with the malformed value in its reason' do
        expect { answer }.to raise_error(UnreadableMessageError)

        expect(gateway).not_to have_received(:submit)
        expect(AuditEvent.last).to have_attributes(
          event_type: 'request_refused',
          detail: include('R-EDM-ebMS-037').and(include('pas-un-uuid')),
        )
      end
    end
  end

  # The mirror of the block above, and the case that says the refusal is not
  # merely strict but *right*: both rules compare what they constrain through
  # `normalize-space()`, so a correspondent whose gateway indents its header
  # sends an identifier the rules accept. Refusing it would drop a conformant
  # request in silence — the very failure this ticket exists to prevent, turned
  # around.
  # Both identifiers, and not just one: they are read through the same helper, so
  # a spec covering `ExchangeId` alone would let `eb:ConversationId` quietly lose
  # its normalisation.
  {
    exchange_id: ['//eb:Property[@name="ExchangeId"]', '1647038b-7eaf-4711-b738-d5d83f96fa7b'],
    conversation_id: ['//eb:ConversationId', '1589c463-ccb7-4c0e-8044-c7198d844c16'],
  }.each do |identifier, (submitted_path, expected)|
    describe "a request whose #{identifier} is valid but surrounded by whitespace" do
      let(:message) { request_with(identifier, "\n      #{expected}\n    ") }

      before { create(:exchange, incoming: true, exchange_id: message.exchange_id) }

      it 'answers it, and answers under the trimmed identifier' do
        answer

        submitted = Nokogiri::XML(gateway_body).at_xpath(submitted_path, OotsNamespaces::NAMESPACES)

        expect(submitted.text).to eq(expected)
      end
    end
  end

  # `IncomingMessage::OpenExchange` turns these away before any handler runs, so
  # this interactor never meets one in production. Pinned all the same: it is a
  # unit of its own, and a reordering of the two guards would otherwise let an
  # unidentified request through to `wrap` unnoticed.
  describe 'a request whose ebMS identifiers are missing altogether' do
    let(:message) { envelope_without('requete', IDENTIFIER_PATHS[:exchange_id]) }

    before { create(:exchange, incoming: true, conversation_id: message.conversation_id) }

    it 'refuses it rather than answering under an identifier it does not have' do
      expect { answer }.to raise_error(UnreadableMessageError, /R-EDM-ebMS-037/)
      expect(gateway).not_to have_received(:submit)
    end
  end

  describe 'a request whose requester cannot be read' do
    let(:message) { envelope_with_body('requete') { |body| body.gsub('>ER<', '>IP<') } }

    # No requester means no final recipient: an answer would be addressed to
    # nobody. The failure has to propagate rather than produce such a message.
    it 'gives up rather than answering nobody' do
      expect { answer }.to raise_error(UnreadableMessageError, /ER/)
      expect(gateway).not_to have_received(:submit)
    end
  end

  # The received request opened its exchange: swallowed here, the failure would
  # leave it pending a sequel that is never coming, and it is `Process` that
  # settles it on seeing the error come back up.
  it 'lets a failure to submit the answer surface' do
    allow(gateway).to receive(:submit).and_raise(Faraday::ConnectionFailed, 'connexion refusée')

    expect { answer }.to raise_error(Faraday::ConnectionFailed)
  end

  it 'answers under the exchange identifier it received' do
    answer

    exchange = Nokogiri::XML(gateway_body).at_xpath('//eb:Property[@name="ExchangeId"]', OotsNamespaces::NAMESPACES)

    expect(exchange.text).to eq(message.exchange_id)
  end

  def gateway_body
    expect(gateway).to have_received(:submit) { |envelope| return envelope }
  end

  # Each identifier addressed by the very path its rule anchors on:
  # `R-EDM-ebMS-017` on the `eb:ConversationId` of the collaboration,
  # `R-EDM-ebMS-037` on the `ExchangeId` message property. Written whole rather
  # than as the element alone, so that what a spec malforms is what the rule
  # reads, and not merely something that shares its name.
  IDENTIFIER_PATHS = {
    conversation_id: '//eb:UserMessage/eb:CollaborationInfo/eb:ConversationId',
    exchange_id: "//eb:UserMessage/eb:MessageProperties/eb:Property[@name='ExchangeId']",
  }.freeze

  # A real request whose header carries the given value for one of the two
  # identifiers, well-formed or not.
  def request_with(identifier, value)
    envelope_where('requete', IDENTIFIER_PATHS.fetch(identifier), value)
  end

  # Forced back to UTF-8: base64 decodes to bytes, and both the parsers and the
  # journal work in text.
  def decoded_payload(envelope)
    Base64.decode64(Nokogiri::XML(envelope).at_xpath('//payload/value').text).force_encoding(Encoding::UTF_8)
  end

  def status_of(document) = document.root['status']

  def available_at_of(document)
    document.at_xpath("//rim:Slot[@name='ResponseAvailableDateTime']//rim:Value", SlotReading::NAMESPACES)&.text
  end

  def request_for(procedure_code)
    envelope_with_body('requete') do |body|
      body.sub(/(<rim:Slot name="Procedure">.*?<rim:Value>)[^<]*/m, "\\1#{procedure_code}")
    end
  end

  def identifier_of(document)
    document.at_xpath("//rim:Slot[@name='EvidenceResponseIdentifier']//rim:Value", SlotReading::NAMESPACES).text
  end

  # « Evidence/Identifier value in EvidenceMetadata Slot (RegRep4) », as chapter
  # 4.8 designates it: the identifier of the document, not of the answer.
  def evidence_identifier_of(document)
    document.at_xpath("//rim:Slot[@name='EvidenceMetadata']//sdg:Evidence/sdg:Identifier",
      SlotReading::NAMESPACES).text
  end

  # The reference the body makes of the attachment, which the ebMS header
  # declares under the same `cid:`.
  def repository_item_ref_of(document)
    document.at_xpath('//rim:RepositoryItemRef/@xlink:href', OotsNamespaces::NAMESPACES).value
  end

  def code_of(document) = exception_of(document)['code']

  def detail_of(document) = exception_of(document)['detail']

  def exception_of(document)
    document.at_xpath('//rs:Exception', 'rs' => 'urn:oasis:names:tc:ebxml-regrep:xsd:rs:4.0')
  end
  # The bridge between answering another member state and closing the exchange
  # opened on receiving its request. Without it, an answer goes out and the
  # exchange stays pending a sequel that is never coming.
  describe 'the exchange France opened on receiving the request' do
    before { create(:exchange, incoming: true, exchange_id: message.exchange_id, country_code: nil) }

    it 'is delivered once the evidence has gone out' do
      answer

      expect(Exchange.sole).to have_attributes(status: 'delivered')
    end

    # A refusal settles the exchange as surely as an answer does: what the
    # correspondent is owed has gone out either way, and an exchange left
    # pending would claim a sequel that is never coming.
    context 'when France refuses what was asked' do
      let(:message) { RetrievedMessageParser.new(real_envelope('requete.demarcheInconnue')) }

      it 'fails under the code France answered with' do
        answer

        expect(Exchange.sole).to have_attributes(status: 'failed', edm_error_code: 'EDM:ERR:0004')
      end
    end
  end

  # The same identifier can name an exchange France opened by asking: settling
  # it here would call it delivered, and the response it is really waiting for
  # would no longer settle it.
  it 'leaves alone an exchange France opened by asking' do
    create(:exchange, exchange_id: message.exchange_id, incoming: false)
    allow(Rails.logger).to receive(:warn)

    answer

    expect(Exchange.sole).to have_attributes(status: 'pending')
  end

  # `IncomingMessage::Process` always opens one, but nothing compels it: the
  # answer goes out all the same, and says so rather than letting it slip.
  it 'answers all the same when no exchange bears the identifier received' do
    expect(Rails.logger).to receive(:warn).with(/#{message.exchange_id}/)

    expect(answer).to be_a_success
  end
end
