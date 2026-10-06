require 'rails_helper'

RSpec.describe MessageErrorsParser do
  subject(:parser) { described_class.new(built_envelope('domibus/erreursRemise')) }

  # The schema promises no order, and the fixture lists the last attempt first.
  it 'takes the last error the gateway recorded where the correspondent signalled none' do
    expect(parser.cause).to have_attributes(code: 'EBMS:0003', detail: 'No matching party found',
      timestamp: Time.iso8601('2026-10-05T10:03:00Z'))
  end

  it 'has no cause where the gateway recorded no error' do
    expect(described_class.new(built_envelope('domibus/erreursRemise.vide')).cause).to be_nil
  end

  # A refusal returned in a SOAP fault: Domibus records the correspondent's
  # code under RECEIVING, then its own EBMS:0005 for the same attempt, later.
  describe 'a refusal the correspondent signalled in a fault' do
    subject(:parser) { described_class.new(built_envelope('domibus/erreursRemise.refusDistant')) }

    it "takes the correspondent's refusal over the gateway's later failure to dispatch" do
      expect(parser.cause).to have_attributes(code: 'EBMS:0003',
        detail: start_with('Sender party could not be found'),
        timestamp: Time.iso8601('2026-10-06T15:29:30.184+02:00'))
    end

    it "takes the correspondent's last refusal whatever the order of the items" do
      document = Nokogiri::XML(built_envelope('domibus/erreursRemise.refusDistant'))
      items = document.xpath('//item')
      items.unlink
      items.reverse_each { |item| document.at_xpath('//*[local-name()="getMessageErrorsResponse"]').add_child(item) }

      expect(described_class.new(document.to_xml).cause.timestamp).to eq(Time.iso8601('2026-10-06T15:29:30.184+02:00'))
    end
  end

  it 'refuses a body that is not the answer to this operation' do
    expect { described_class.new(real_envelope('soumissionMessage')) }.to raise_error(UnreadableMessageError)
  end
end
