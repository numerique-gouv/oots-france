require 'rails_helper'

RSpec.describe EvidenceForwarder do
  subject(:forwarder) { described_class.new }

  let(:requester) { EvidenceRequester.french(id: '00000000000002', name: 'Requêteur', url: 'https://fournisseur.example') }
  let(:exchange) { create(:exchange) }
  let(:evidence) { MimePart.new(mime_type: EvidenceType::PDF, content_id: 'cid:justificatif', content: "%PDF-1.4\nfake".b) }

  before { stub_request(:post, %r{https://fournisseur\.example/oots/document}).to_return(status: 200) }

  it 'posts the evidence to the address the requester publishes' do
    forwarder.deliver(evidence, requester, exchange)

    expect(a_request(:post, %r{https://fournisseur\.example/oots/document})
      .with(body: evidence.content, headers: { 'Content-Type' => EvidenceType::PDF })).to have_been_made
  end

  # Under the type the response declared for the part, which is the format the
  # exchange requested: the portal saves what it receives, and reads the type
  # to know what that is.
  it 'sends the evidence under the type it arrived with' do
    json = MimePart.new(mime_type: 'application/json', content_id: 'cid:justificatif', content: '{"statut":"inscrit"}')

    forwarder.deliver(json, requester, exchange)

    expect(a_request(:post, %r{https://fournisseur\.example/oots/document})
      .with(body: json.content, headers: { 'Content-Type' => 'application/json' })).to have_been_made
  end

  # Chapter 4.4 §4.3.2: an `ExchangeId` that « correlate[s] all messages
  # belonging to a single Evidence Request-Response exchange », and a
  # `ConversationId` whose messages « MUST relate to that user ». Both, because
  # a service provider leading two users at once places a delivery on neither
  # without them — and under the names
  # `GET /requete/:exchange_id` answers, so that one vocabulary reaches a caller.
  it 'carries the two identifiers the receiver correlates on' do
    forwarder.deliver(evidence, requester, exchange)

    expect(a_request(:post, 'https://fournisseur.example/oots/document')
      .with(query: { echange: exchange.exchange_id, conversation: exchange.conversation_id }))
      .to have_been_made
  end

  # The body is the evidence and nothing else: the receiver saves it to a file, and a
  # JSON envelope would have it unpack a serialised byte array first.
  it 'sends the evidence as its own bytes, wrapped in nothing' do
    forwarder.deliver(evidence, requester, exchange)

    expect(a_request(:post, %r{https://fournisseur\.example/oots/document})
      .with { |request| request.body == evidence.content }).to have_been_made
  end
end
