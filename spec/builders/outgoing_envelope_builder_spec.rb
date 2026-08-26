require 'rails_helper'

RSpec.describe OutgoingEnvelopeBuilder do
  subject(:builder) { described_class.new(body:, **attributes) }

  # A double rather than a real body builder, so that the count of renders is
  # observable: what this class owes its caller is that the part it hands to the
  # journal is the one it put in the envelope.
  let(:body) do
    instance_double(EvidenceRequestBuilder, document_id: '1a2b3c4d-0000-4000-8000-000000000000',
      render: '<query:QueryRequest/>')
  end

  let(:attributes) do
    {
      action: EbmsAction::EXECUTE_QUERY_REQUEST,
      recipient: AccessPoint.new(id: 'DE73524311', type_id: 'urn:cef.eu:names:identifier:EAS:9930'),
      original_sender: EbmsIdentity.new(id: '00000000000002', type_id: 'urn:cef.eu:names:identifier:EAS:0009'),
      final_recipient: EbmsIdentity.new(id: 'DE73524311', type_id: 'urn:cef.eu:names:identifier:EAS:9930'),
      conversation_id: '1589c463-ccb7-4c0e-8044-c7198d844c16',
      exchange_id: '1647038b-7eaf-4711-b738-d5d83f96fa7b',
    }
  end

  # Chapter 4.7.1 fixes the type of `eb:PartInfo[1]`, and chapter 4.8 has the
  # log keep both it and the content whole. The reference is the one the header
  # declares and the submission carries, minted once for both.
  it 'hands back the part it put in the envelope' do
    envelope = Nokogiri::XML(builder.render)
    carried = envelope.at_xpath('//payload/value').text

    expect(builder.first_part).to eq(
      MimePart.new(mime_type: EbmsHeaderBuilder::REGREP_MIME_TYPE,
        content_id: envelope.at_xpath('//payload')['payloadId'],
        content: Base64.strict_decode64(carried)),
    )
  end

  # `EbmsHeaderBuilder` draws a message identifier and a timestamp in its
  # constructor, so this envelope is not idempotent: were the journal to render
  # the body a second time, it could as easily render the envelope a second time
  # and record a message identifier the gateway never saw.
  it 'renders the body once, however often the part is asked for' do
    3.times { builder.first_part }
    builder.render

    expect(body).to have_received(:render).once
  end
end
