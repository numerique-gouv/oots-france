require 'rails_helper'

RSpec.describe 'Demo::EvidenceDeliveries' do
  let(:content) { "%PDF-1.4\ndrapeau".b }
  let(:query) do
    { echange: DemoContractStubs::ACCEPTED_EXCHANGE, conversation: DemoContractStubs::ACCEPTED_CONVERSATION }
  end

  def deliver(**overrides)
    post '/demo/oots/document', params: content, headers: { 'CONTENT_TYPE' => Attachment::MIME_TYPE },
      env: { 'QUERY_STRING' => query.merge(overrides).to_query }
  end

  # The address is a service provider's, not the console's: `EvidenceForwarder`
  # calls it from a worker, with no session and no operator behind it.
  it 'takes a delivery without any operator being signed in' do
    registered_request

    deliver

    expect(response).to have_http_status(:created)
  end

  # CA1, first half: the bytes are filed as they arrived.
  it 'files the evidence on the request that asked for it' do
    registered_request

    deliver

    expect(Demo::Request.sole.evidence).to eq(content)
  end

  # CA5. Chapter 4.10 §4.1, informative, has an unplaceable delivery logged for
  # investigation and asks for nothing more; refusing it as well is this
  # procedure's decision, so that the exchange is accounted for on the side that
  # opened it — `EvidenceForwarder` raises on the status.
  it 'refuses a delivery naming an exchange it never opened' do
    deliver(echange: 'cccccccc-0000-4000-8000-000000000009')

    expect(response).to have_http_status(:not_found)
    expect(Demo::Request.count).to be_zero
  end

  it 'refuses a delivery carrying no bytes' do
    registered_request

    post '/demo/oots/document', params: '', headers: { 'CONTENT_TYPE' => Attachment::MIME_TYPE },
      env: { 'QUERY_STRING' => query.to_query }

    expect(response).to have_http_status(:unprocessable_content)
  end
end
