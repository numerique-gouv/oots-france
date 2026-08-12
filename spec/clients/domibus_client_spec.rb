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

  describe '#find_access_point' do
    let(:party) do
      [{ 'identifiers' => [{ 'partyId' => 'blue_gw', 'partyIdType' => { 'value' => 'urn:…:unregistered:oots' } }] }]
    end

    it 'resolves a party of the PMode into an access point' do
      stub_request(:get, "#{base_url}/ext/party").with(query: { name: 'blue_gw' })
        .to_return(body: party.to_json)

      expect(client.find_access_point('blue_gw'))
        .to have_attributes(id: 'blue_gw', type_id: 'urn:…:unregistered:oots')
    end

    # An access point without a scheme reaches Domibus as a property it accepts
    # and routes nowhere. Failing at the lookup names what is wrong.
    it 'refuses a party the PMode declares without an identifier scheme' do
      incomplete = [{ 'identifiers' => [{ 'partyId' => 'blue_gw' }] }]
      stub_request(:get, "#{base_url}/ext/party").with(query: { name: 'blue_gw' })
        .to_return(body: incomplete.to_json)

      expect { client.find_access_point('blue_gw') }
        .to raise_error(ConfigurationError, /Le point d'accès « blue_gw »/)
    end

    it 'refuses to look up a recipient that was never named' do
      expect { client.find_access_point(nil) }.to raise_error(RecipientNotFound, /non renseigné/)
    end

    # The PMode is the only directory this deployment has: a correspondent it
    # does not declare is unreachable, and saying so plainly is what tells an
    # operator the PMode is what needs changing.
    it 'says so when the PMode does not declare the party' do
      stub_request(:get, "#{base_url}/ext/party").with(query: { name: 'inconnu' }).to_return(body: '[]')

      expect { client.find_access_point('inconnu') }
        .to raise_error(RecipientNotFound, /Point d'accès inexistant : inconnu/)
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
