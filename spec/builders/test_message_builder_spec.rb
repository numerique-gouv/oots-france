require 'rails_helper'

RSpec.describe TestMessageBuilder do
  subject(:document) { Nokogiri::XML(described_class.new(recipient:, sender:).render) }

  let(:recipient) { EbmsIdentity.new(id: 'AP_EL_01', type_id: 'urn:oasis:names:tc:ebcore:partyid-type:unregistered:EL') }
  let(:sender) { AccessPoint.new(id: 'AP_FR_01', type_id: 'urn:oasis:names:tc:ebcore:partyid-type:unregistered:FR') }
  let(:namespaces) { OotsNamespaces::NAMESPACES }

  def text(path) = document.at_xpath(path, namespaces)&.text

  it 'is well-formed' do
    expect(document.errors).to be_empty
  end

  it 'carries the service and the action of the ebMS test service, untyped' do
    service = document.at_xpath('//eb:CollaborationInfo/eb:Service', namespaces)

    expect(service.text).to eq('http://docs.oasis-open.org/ebxml-msg/ebms/v3.0/ns/core/200704/service')
    expect(service['type']).to be_nil
    expect(text('//eb:CollaborationInfo/eb:Action')).to eq('http://docs.oasis-open.org/ebxml-msg/ebms/v3.0/ns/core/200704/test')
  end

  it 'goes from France to the party, both in the gateway role' do
    expect(text('//eb:From/eb:PartyId')).to eq('AP_FR_01')
    expect(document.at_xpath('//eb:To/eb:PartyId', namespaces)['type'])
      .to eq('urn:oasis:names:tc:ebcore:partyid-type:unregistered:EL')
    expect(text('//eb:To/eb:PartyId')).to eq('AP_EL_01')
    expect(document.xpath('//eb:Role', namespaces).map(&:text)).to all(eq(AccessPoint::ROLE))
  end

  it 'gives C1 and C4 the values of the gateway\'s own test message, untyped' do
    properties = document.xpath('//eb:MessageProperties/eb:Property', namespaces)

    expect(properties.to_h { |property| [property['name'], property.text] }).to eq(
      'originalSender' => 'urn:oasis:names:tc:ebcore:partyid-type:unregistered:C1',
      'finalRecipient' => 'urn:oasis:names:tc:ebcore:partyid-type:unregistered:C4',
    )
    expect(properties.pluck('type')).to all(be_nil)
  end

  it 'carries no payload' do
    expect(document.xpath('//ws:submitRequest/*', namespaces)).to be_empty
    expect(document.at_xpath('//eb:PayloadInfo', namespaces)).to be_nil
  end

  it 'escapes the identity of the party' do
    recipient.id = '</eb:PartyId><injecte/>'

    expect(document.errors).to be_empty
    expect(document.at_xpath('//injecte')).to be_nil
  end
end
