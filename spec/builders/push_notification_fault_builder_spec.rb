require 'rails_helper'

RSpec.describe PushNotificationFaultBuilder do
  let(:soap) { { 'soap' => 'http://www.w3.org/2003/05/soap-envelope' } }
  let(:document) { Nokogiri::XML(described_class.new.render) }
  let(:fault) { document.at_xpath('/soap:Envelope/soap:Body/soap:Fault', soap) }

  it 'renders a well-formed SOAP 1.2 fault' do
    expect(document.errors).to be_empty
    expect(fault).not_to be_nil
  end

  it 'blames the sender, in the SOAP 1.2 namespace' do
    prefix, local_name = fault.at_xpath('soap:Code/soap:Value', soap).text.split(':')

    expect([fault.namespaces["xmlns:#{prefix}"], local_name]).to eq([soap['soap'], 'Sender'])
  end

  it 'gives the reason SOAP 1.2 requires, with its language' do
    text = fault.at_xpath('soap:Reason/soap:Text', soap)

    expect(text['xml:lang']).to eq('en')
    expect(text.text).not_to be_empty
  end

  it 'carries no detail' do
    expect(fault.at_xpath('soap:Detail', soap)).to be_nil
  end
end
