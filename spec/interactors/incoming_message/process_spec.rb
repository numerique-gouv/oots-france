require 'rails_helper'

RSpec.describe IncomingMessage::Process do
  subject(:process) { described_class.call(message_id: 'un-message', gateway:, **collaborators) }

  let(:collaborators) do
    {
      evidence_forwarder: instance_double(EvidenceForwarder),
      requesters: Directories::EvidenceRequesters.new(
        '00000000000002' => { 'nom' => 'Requêteur', 'url' => 'http://localhost:4000' },
      ),
      uuid: UuidGenerator.new,
      audit_trail: AuditTrail.new,
    }
  end
  let(:gateway) { instance_double(DomibusClient, retrieve: message) }
  let(:message) { RetrievedMessageParser.new(real_envelope('requete')) }

  it 'hands an incoming request to the interactor that answers it' do
    allow(EvidenceProvision::AnswerRequest).to receive(:call!)

    process

    expect(EvidenceProvision::AnswerRequest).to have_received(:call!)
  end

  # Opened here from the body that was parsed here, and asserted on the whole
  # path rather than on a double: what `OpenExchange` reads is the message
  # `Process` retrieved, and nothing else says the two are the same object.
  it 'opens the exchange an incoming request names' do
    allow(EvidenceProvision::AnswerRequest).to receive(:call!)

    process

    # Both identifiers, read from a real envelope by the real parser: chapter 4.4
    # keeps them apart, and the fixtures carry two different values, so an
    # assertion on one alone would pass on code that stored the other twice.
    expect(Exchange.sole).to have_attributes(
      exchange_id: message.exchange_id, conversation_id: message.conversation_id, incoming: true,
      procedure_code: '00', country_code: 'FR', evidence_requester_id: '00000000000002',
    )
    expect(message.exchange_id).not_to eq(message.conversation_id)
  end

  # Journalled in `Process`, before the handler: `SettleExchange` returns
  # early on an exchange it never opened, and the trace would go with it.
  it 'journals a response naming an exchange it never opened' do
    allow(gateway).to receive(:retrieve).and_return(RetrievedMessageParser.new(real_envelope('erreurObjetIntrouvable')))

    process

    expect(AuditEvent.last).to have_attributes(event_type: 'error_received', edm_error_code: 'EDM:ERR:0004')
    expect(Exchange.count).to eq(0)
  end

  it 'hands an incoming response to the interactor that settles the exchange' do
    allow(gateway).to receive(:retrieve).and_return(RetrievedMessageParser.new(real_envelope('erreurObjetIntrouvable')))
    allow(IncomingMessage::SettleExchange).to receive(:call!)

    process

    expect(IncomingMessage::SettleExchange).to have_received(:call!)
  end

  describe 'an action it does not know' do
    let(:message) do
      RetrievedMessageParser.new(real_envelope('requete').sub('ExecuteQueryRequest', 'SomethingElse'))
    end

    # An unknown action must leave a trace. The message has arrived and the
    # gateway has erased it, so a lookup that merely returns nil leaves no log,
    # no answer and no record that anything came at all — the one outcome that
    # teaches nobody anything.
    it 'says so in the log rather than dropping the message silently' do
      allow(Rails.logger).to receive(:error)

      process

      expect(Rails.logger).to have_received(:error).with(/Action ebMS inconnue/)
    end

    it 'does not raise, the message being gone from the gateway anyway' do
      expect { process }.not_to raise_error
    end

    # The application log rotates and is addressed to whoever runs the
    # deployment; this line is addressed to an auditor and lasts twelve months.
    it 'journals the arrival, naming the action and keeping the body' do
      process

      expect(AuditEvent.sole).to have_attributes(
        event_type: 'message_unhandled',
        ebms_action: 'SomethingElse',
        message_id: 'un-message',
        exchange_id: message.exchange_id,
        conversation_id: message.conversation_id,
        regrep_mime_type: RetrievedMessageParser::REGREP,
      )
      expect(AuditEvent.sole.regrep_body).to include('QueryRequest')
    end

    # `sole` above already says it, and this says why it matters: a line
    # claiming a request was received would have the replay check of chapter 4.4
    # turn away the correspondent's next attempt at the same identifier.
    it 'writes no line claiming the message was received' do
      process

      expect(AuditEvent.where(event_type: 'request_received')).to be_empty
    end
  end

  describe 'a message whose body it cannot read' do
    # The header parses — so the exchange is known — and the body does not.
    let(:message) { RetrievedMessageParser.new(real_envelope('erreurObjetIntrouvable')) }

    let!(:exchange) do
      create(:exchange, exchange_id: message.exchange_id).tap(&:sent!)
    end

    before { allow(message).to receive(:body).and_raise(UnreadableMessageError, 'corps illisible') }

    it 'logs it' do
      allow(Rails.logger).to receive(:error)

      process

      expect(Rails.logger).to have_received(:error).with(/corps illisible/)
    end

    # Left in `sent`, the exchange would stay open for ever on an answer that
    # has already arrived and been discarded.
    it 'marks the exchange waiting on it as failed rather than leaving it hanging' do
      process

      expect(exchange.reload).to have_attributes(status: 'failed')
    end
  end

  # The seam between the two: `AuditTrail` swallows an unreadable first part so
  # the line survives, and this interactor rescues the same exception to abandon
  # the exchange. The one must not reach the other, or a message whose bytes we
  # merely could not keep would be treated as a message we could not read.
  describe 'a message whose first MIME part cannot be captured' do
    let(:message) { RetrievedMessageParser.new(real_envelope('requete')) }

    before { allow(message).to receive(:first_part).and_raise(UnreadableMessageError, 'partie illisible') }

    it 'journals the arrival without the part, and dispatches all the same' do
      allow(EvidenceProvision::AnswerRequest).to receive(:call!)

      process

      expect(AuditEvent.find_by(event_type: 'request_received', exchange_id: message.exchange_id)).to have_attributes(
        regrep_mime_type: nil,
        regrep_body: nil,
        request_id: 'urn:uuid:cdd87e02-2bdc-4ce6-bdc9-79e05adae700',
      )
      expect(Exchange.find_by(exchange_id: message.exchange_id)).to be_present
      expect(EvidenceProvision::AnswerRequest).to have_received(:call!)
    end
  end

  # Only the deferral of chapter 4.5.2 excuses a response without evidence, and
  # it says so in its status. One claiming `Success` and carrying nothing is
  # unreadable, which is what this side has always made of it.
  describe 'a response claiming success and carrying no evidence' do
    let(:message) do
      namespaces = OotsNamespaces::NAMESPACES
      document = Nokogiri::XML(real_envelope('reponseAvecPieceJointe'))
      document.xpath('//eb:PartInfo', namespaces).find { |part|
        part.at_xpath('.//eb:Property[@name="MimeType"]', namespaces)&.text == RetrievedMessageParser::PDF
      }.remove

      RetrievedMessageParser.new(document.to_xml)
    end

    let!(:conversation) do
      create(:exchange, exchange_id: message.exchange_id).tap(&:sent!)
    end

    it 'settles the exchange as a failure' do
      process

      expect(conversation.reload).to have_attributes(status: 'failed')
    end
  end

  # There is nothing to fall back on here: the identifier the gateway gave us
  # is its own, and only the message it refuses to hand over would have named
  # the exchange. Which is why the sweep exists — and why the line the journal
  # keeps is worth what its `message_id` opens in the console's *Message Log*.
  describe 'a message whose envelope cannot be read at all' do
    before { allow(gateway).to receive(:retrieve).and_raise(UnreadableMessageError, 'enveloppe illisible') }

    it 'logs it, and does not raise' do
      allow(Rails.logger).to receive(:error)

      expect { process }.not_to raise_error
      expect(Rails.logger).to have_received(:error).with(/enveloppe illisible/)
    end

    it 'journals the identifier the gateway gave, and the reason nothing else could be read' do
      process

      expect(AuditEvent.sole).to have_attributes(
        event_type: 'message_unreadable', message_id: 'un-message', detail: 'enveloppe illisible',
        exchange_id: nil, ebms_action: nil, regrep_body: nil,
      )
    end

    # A gateway that answered nothing erased nothing: the message is still
    # pending and the sweep will come back for it, so a line saying it was lost
    # would be false.
    it 'writes no line when the gateway did not answer at all' do
      allow(gateway).to receive(:retrieve).and_raise(Faraday::ConnectionFailed, 'connexion refusée')

      expect { process }.to raise_error(Faraday::ConnectionFailed)
      expect(AuditEvent.count).to eq(0)
    end
  end

  # Both failures below are answered the same way, and each example asserts the
  # two halves of it together. Split in two, the half that re-raises passes
  # whether the rescue is there or not — an unrescued error reaches the caller
  # just as surely — and would keep a green tick over a clause someone deleted.
  describe 'a message that names its exchange but cannot be seen through' do
    let(:message) { RetrievedMessageParser.new(real_envelope('reponseAvecPieceJointe')) }

    let!(:exchange) do
      create(:exchange, exchange_id: message.exchange_id).tap(&:sent!)
    end

    # Retrying is not an option: the PMode erases a message once retrieved, so a
    # second attempt would read nothing and would no longer even know which
    # exchange it concerned. Nor is staying quiet: France answering another
    # member state opens no exchange of its own, so on that path a job
    # recorded as failed is the only signal there is.
    describe 'a network failure after the message was retrieved' do
      before do
        allow(collaborators[:evidence_forwarder]).to receive(:deliver)
          .and_raise(Faraday::ConnectionFailed, 'connexion refusée')
      end

      it 'settles the exchange, and still lets the failure surface' do
        expect { process }.to raise_error(Faraday::ConnectionFailed)
        expect(exchange.reload).to have_attributes(status: 'failed')
      end
    end

    # `EbmsError` serves the synchronous path, where the controller turns it
    # into a 422 for the caller at fault. Nothing catches it in a job, so
    # unless this path settles the exchange itself it stays in `sent` for
    # ever. Ours to fix, not the correspondent's: the entry is missing from the
    # directory the environment carries, and no retry conjures it back.
    describe 'an answer whose requester the directory no longer holds' do
      before { collaborators[:requesters] = Directories::EvidenceRequesters.new({}) }

      it 'settles the exchange, and still lets the failure surface' do
        expect { process }.to raise_error(EvidenceRequesterNotFound)
        expect(exchange.reload).to have_attributes(status: 'failed')
      end
    end
  end

  # The reason travels as a symbol. The branches that give one are exercised
  # above, but never for the wording their reason resolves to: nothing else
  # would notice a missing one.
  it 'says every reason it abandons an exchange for' do
    given_up = File.read('app/interactors/incoming_message/process.rb')
      .scan(/abandon_exchange\(\w+, :(\w+)\)/).flatten.uniq

    expect_said(given_up.map { |reason| "interactors.incoming_message.process.#{reason}" })
  end
end
