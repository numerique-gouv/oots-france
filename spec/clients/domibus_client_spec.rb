require 'rails_helper'

RSpec.describe DomibusClient do
  subject(:client) { described_class.new }

  let(:base_url) { 'http://domibus:8080/domibus' }

  before do
    allow(Settings).to receive_messages(
      domibus_base_url: base_url,
      domibus_credentials: { login: 'oots', password: 'secret' },
    )
  end

  describe '#submit' do
    it 'posts the envelope as XML and reads back the identifier the gateway gave it' do
      stub = stub_request(:post, "#{base_url}/services/wsplugin/submitMessage")
        .with(headers: { 'Content-Type' => 'text/xml' })
        .to_return(body: real_envelope('soumissionMessage'))

      expect(client.submit('<soap:Envelope/>').message_id).to eq('45fa5345-5a18-4691-945f-531f9568729f@oots.eu')
      expect(stub).to have_been_requested
    end

    it 'authenticates with the plugin credentials' do
      stub = stub_request(:post, "#{base_url}/services/wsplugin/submitMessage")
        .with(basic_auth: %w[oots secret])
        .to_return(body: real_envelope('soumissionMessage'))

      client.submit('<soap:Envelope/>')

      expect(stub).to have_been_requested
    end

    # The plugin answers a refused submission with a `500` whose fault says why;
    # Faraday's own message says only the status and the address.
    describe 'a submission the gateway refuses with a fault' do
      def refuse_with(status: 500, body: built_envelope('domibus/soumissionRefusee'))
        stub_request(:post, "#{base_url}/services/wsplugin/submitMessage").to_return(status:, body:)
      end

      it 'raises with the code and the message of the fault' do
        refuse_with

        expect { client.submit('<soap:Envelope/>') }.to raise_error(SubmissionRefused) { |error|
          expect(error.message).to include('EBMS:0003', 'Receiver party could not be found for the value')
          expect(error.message).not_to include('status 500', base_url)
        }
      end

      it 'stays a Faraday error, which every caller already rescues, and keeps the answer' do
        refuse_with

        expect { client.submit('<soap:Envelope/>') }.to raise_error(Faraday::Error) { |error|
          expect(error.response[:status]).to eq(500)
          expect(error.response[:body]).to include('FaultDetail')
        }
      end

      it 'carries a code of the plugin as it comes' do
        refuse_with(body: built_envelope('domibus/soumissionRefusee')
          .sub('<code>EBMS:0003</code>', '<code>WS_PLUGIN_0005</code>')
          .sub(%r{<message>.*</message>}, '<message>Invalid request</message>'))

        expect { client.submit('<soap:Envelope/>') }
          .to raise_error(SubmissionRefused, 'WS_PLUGIN_0005 : Invalid request')
      end

      it 'carries the code alone of a fault that gives no message' do
        refuse_with(body: built_envelope('domibus/soumissionRefusee').sub(%r{<message>.*</message>}, ''))

        expect { client.submit('<soap:Envelope/>') }.to raise_error(SubmissionRefused, 'EBMS:0003')
      end

      it 'carries the message of a fault detail that gives no code' do
        refuse_with(body: built_envelope('domibus/soumissionRefusee').sub('<code>EBMS:0003</code>', ''))

        expect { client.submit('<soap:Envelope/>') }
          .to raise_error(SubmissionRefused, /\AValueInconsistent detail: Receiver party could not be found/)
      end

      it 'carries the reason of a fault that gives no code' do
        refuse_with(body: built_envelope('domibus/soumissionRefusee').sub(%r{<soap:Detail>.*</soap:Detail>}, ''))

        expect { client.submit('<soap:Envelope/>') }.to raise_error(SubmissionRefused, 'Message submission failed')
      end
    end

    describe 'a submission refused without a fault' do
      it 'lets an answer that is no SOAP envelope through as it came' do
        stub_request(:post, "#{base_url}/services/wsplugin/submitMessage").to_return(status: 502, body: 'Bad Gateway')

        expect { client.submit('<soap:Envelope/>') }
          .to raise_error(Faraday::ServerError, "the server responded with status 502 for POST #{base_url}/services/wsplugin/submitMessage")
      end

      it 'lets a connection that failed through as it came' do
        stub_request(:post, "#{base_url}/services/wsplugin/submitMessage").to_raise(Faraday::ConnectionFailed.new('connexion refusée'))

        expect { client.submit('<soap:Envelope/>') }.to raise_error(Faraday::ConnectionFailed, 'connexion refusée')
      end
    end
  end

  describe '#message_errors' do
    it 'asks for the errors of one message and reads what made the attempts fail' do
      stub = stub_request(:post, "#{base_url}/services/wsplugin/getMessageErrors")
        .with(body: %r{<messageID>8a1c0e3f-7b2d-4c6e-9f10-2d3e4f5a6b7c@oots.eu</messageID>})
        .to_return(body: built_envelope('domibus/erreursRemise'))

      expect(client.message_errors('8a1c0e3f-7b2d-4c6e-9f10-2d3e4f5a6b7c@oots.eu').cause.code).to eq('EBMS:0003')
      expect(stub).to have_been_requested
    end

    # The plugin answers a message it does not know with a SOAP fault.
    it 'lets a fault of the gateway through' do
      stub_request(:post, "#{base_url}/services/wsplugin/getMessageErrors").to_return(status: 500)

      expect { client.message_errors('inconnu') }.to raise_error(Faraday::ServerError)
    end
  end

  describe '#message_errors with a role' do
    it 'asks for the errors of the side France stood on' do
      stub = stub_request(:post, "#{base_url}/services/wsplugin/getMessageErrorsWithAccessPointRole")
        .with(body: %r{<accessPointRole>SENDING</accessPointRole>})
        .to_return(body: built_envelope('domibus/erreursRemise.connexion'))

      expect(client.message_errors('test@domibus.eu', role: 'SENDING').cause.code).to eq('EBMS:0005')
      expect(stub).to have_been_requested
    end
  end

  describe '#message_status' do
    it 'reads the status of the side France stood on' do
      stub = stub_request(:post, "#{base_url}/services/wsplugin/getStatusWithAccessPointRole")
        .with(body: %r{<messageID>test@domibus.eu</messageID>\s*<accessPointRole>SENDING</accessPointRole>})
        .to_return(body: built_envelope('domibus/statutAcquitte'))

      expect(client.message_status('test@domibus.eu', role: 'SENDING')).to be_acknowledged
      expect(stub).to have_been_requested
    end
  end

  describe '#pending_messages' do
    it 'reports an empty queue' do
      stub_request(:post, "#{base_url}/services/wsplugin/listPendingMessages")
        .to_return(body: real_envelope('listeMessagesEnAttente.vide'))

      expect(client.pending_messages.message_ids).to be_empty
    end

    it 'reads the identifier of a message waiting for us' do
      stub_request(:post, "#{base_url}/services/wsplugin/listPendingMessages")
        .to_return(body: real_envelope('listeMessagesEnAttente'))

      expect(client.pending_messages.message_ids).to eq(['45fa5345-5a18-4691-945f-531f9568729f@oots.eu'])
    end

    it 'filters on a conversation when asked to' do
      stub = stub_request(:post, "#{base_url}/services/wsplugin/listPendingMessages")
        .with(body: %r{<conversationId>abc</conversationId>})
        .to_return(body: real_envelope('listeMessagesEnAttente.vide'))

      client.pending_messages(conversation_id: 'abc')

      expect(stub).to have_been_requested
    end
  end

  describe '#retrieve' do
    it 'names the message it wants and parses what comes back' do
      stub = stub_request(:post, "#{base_url}/services/wsplugin/retrieveMessage")
        .with(body: %r{<messageID>un-message</messageID>})
        .to_return(body: real_envelope('requete'))

      expect(client.retrieve('un-message').action).to eq(EbmsAction::EXECUTE_QUERY_REQUEST)
      expect(stub).to have_been_requested
    end
  end

  it 'reads the gateway URL at each call, never memoising it at load time' do
    allow(Settings).to receive(:domibus_base_url).and_return('http://ailleurs:8080/domibus')
    stub = stub_request(:post, 'http://ailleurs:8080/domibus/services/wsplugin/submitMessage')
      .to_return(body: real_envelope('soumissionMessage'))

    described_class.new.submit('<soap:Envelope/>')

    expect(stub).to have_been_requested
  end
end
