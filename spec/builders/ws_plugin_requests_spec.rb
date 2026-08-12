require 'rails_helper'

# The two service requests the WS plugin answers, beside `submitMessage`.
RSpec.describe 'Les requêtes du plugin WS' do
  let(:wsplugin) { { '_1' => 'http://eu.domibus.wsplugin/' } }

  describe ListPendingMessagesBuilder do
    it 'asks for the whole queue when no conversation is named' do
      request = described_class.new.render

      expect(Nokogiri::XML(request).errors).to be_empty
      expect(request).not_to include('conversationId')
    end

    it 'filters on a conversation when one is given' do
      request = described_class.new(conversation_id: 'e0a6a5b7-6b2e-4b9c-9a63-8f0c6d3a1b24').render
      filter = Nokogiri::XML(request).at_xpath('//_1:listPendingMessagesRequest/conversationId', wsplugin)

      expect(filter.text).to eq('e0a6a5b7-6b2e-4b9c-9a63-8f0c6d3a1b24')
    end
  end

  describe RetrieveMessageBuilder do
    it 'names the message to fetch' do
      request = described_class.new(message_id: '45fa5345-5a18-4691-945f-531f9568729f@oots.eu').render
      identifier = Nokogiri::XML(request).at_xpath('//_1:retrieveMessageRequest/messageID', wsplugin)

      expect(Nokogiri::XML(request).errors).to be_empty
      expect(identifier.text).to eq('45fa5345-5a18-4691-945f-531f9568729f@oots.eu')
    end

    # These identifiers come from the gateway rather than from a correspondent,
    # but the escaping is applied all the same: the rule is that every
    # interpolated value which is not a literal goes through it, and an
    # exception invites the next one.
    it 'escapes an identifier that would otherwise break the envelope' do
      request = described_class.new(message_id: '</messageID><injecte/>').render

      expect(Nokogiri::XML(request).errors).to be_empty
      expect(request).not_to include('<injecte/>')
    end
  end
end
