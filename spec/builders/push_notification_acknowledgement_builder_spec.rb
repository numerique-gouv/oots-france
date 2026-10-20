require 'rails_helper'

RSpec.describe PushNotificationAcknowledgementBuilder do
  let(:soap) { { 'soap' => 'http://www.w3.org/2003/05/soap-envelope' } }

  it 'renders a SOAP 1.2 envelope whose body carries nothing' do
    document = Nokogiri::XML(described_class.new.render)
    body = document.at_xpath('/soap:Envelope/soap:Body', soap)

    expect(document.errors).to be_empty
    expect(body.element_children).to be_empty
  end
end
