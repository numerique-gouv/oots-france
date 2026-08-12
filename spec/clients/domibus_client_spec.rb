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
