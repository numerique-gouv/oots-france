require 'rails_helper'

RSpec.describe SubmitMessageBuilder do
  subject(:envelope) { described_class.new(**attributes).render }

  let(:attributes) do
    {
      body: '<query:QueryRequest/>',
      header: '<eb:Messaging xmlns:eb="http://docs.oasis-open.org/ebxml-msg/ebms/v3.0/ns/core/200704/"/>',
      payload_id: 'cid:1a2b3c4d-0000-4000-8000-000000000000@oots.eu',
    }
  end

  it 'is well-formed XML' do
    expect(Nokogiri::XML(envelope).errors).to be_empty
  end

  it 'carries the ebMS header in the SOAP header' do
    header = Nokogiri::XML(envelope).at_xpath('//soap:Header/eb:Messaging', OotsNamespaces::NAMESPACES)

    expect(header).to be_present
  end

  it 'carries the message base64-encoded, under the payload identifier the header declares' do
    payload = Nokogiri::XML(envelope).at_xpath('//payload')

    expect(payload['payloadId']).to eq('cid:1a2b3c4d-0000-4000-8000-000000000000@oots.eu')
    expect(Base64.strict_decode64(payload.at_xpath('value').text)).to eq('<query:QueryRequest/>')
  end

  # `encode64` breaks its output every 60 characters, which is legal MIME and
  # pointless inside an element. A message long enough to wrap is the only way
  # to notice.
  it 'encodes on a single line, however long the message' do
    long_body = "<query:QueryRequest>#{'x' * 500}</query:QueryRequest>"
    payload = Nokogiri::XML(described_class.new(**attributes, body: long_body).render).at_xpath('//payload/value')

    expect(payload.text).not_to include("\n")
  end

  describe 'the attachment' do
    subject(:with_attachment) do
      described_class.new(**attributes, attachment: Attachment.new('cid:1111@pdf.oots.fr', 'JVBERi0xLjQK')).render
    end

    it 'is absent when there is none' do
      expect(Nokogiri::XML(envelope).xpath('//payload').size).to eq(1)
    end

    it 'travels as a second payload' do
      expect(Nokogiri::XML(with_attachment).xpath('//payload').size).to eq(2)
    end

    # A deliberate divergence from the reference envelopes, documented in
    # `spec/fixtures/README.md`: they wrap the content in literal parentheses,
    # which is not base64 and only travels because a MIME decoder skips
    # characters outside the alphabet. The first suspect should an exchange
    # fail at the gateway.
    it 'holds base64 and nothing else, no parentheses around it' do
      content = Nokogiri::XML(with_attachment).xpath('//payload/value').last.text

      expect(content).to eq('JVBERi0xLjQK')
      expect { Base64.strict_decode64(content) }.not_to raise_error
    end
  end
end
