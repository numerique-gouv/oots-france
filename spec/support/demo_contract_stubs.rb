# The contract of `GET /requete/pieceJustificative` as the demonstration
# procedure meets it — from the outside, over HTTP, exactly as the server of a
# French service provider meets it.
#
# Stubbed at the HTTP boundary and not at `Demo::EvidenceRequestClient`: what
# these examples are about is that the procedure goes through the contract at
# all, and a double standing in for the client would prove only that a method
# was called.
module DemoContractStubs
  PATH = '/requete/pieceJustificative'.freeze

  ACCEPTED_EXCHANGE = 'aaaaaaaa-0000-4000-8000-000000000001'.freeze
  ACCEPTED_CONVERSATION = 'bbbbbbbb-0000-4000-8000-000000000001'.freeze

  # The key this deployment publishes for a requester to encrypt a beneficiary
  # token with, and which the procedure has to read rather than derive.
  def oots_france_key = @oots_france_key ||= OpenSSL::PKey::RSA.generate(2048)

  def stub_oots_france_public_keys
    stub_request(:get, "#{Settings.oots_france_url}/auth/cles_publiques")
      .to_return(body: { keys: [JWT::JWK.new(oots_france_key).export] }.to_json,
        headers: { 'Content-Type' => 'application/json' })
  end

  def stub_evidence_request(status: 202, body: nil)
    stub_request(:get, "#{Settings.oots_france_url}#{PATH}")
      .with(query: hash_including({}))
      .to_return(status:, body: body || accepted_body.to_json,
        headers: { 'Content-Type' => 'application/json' })
  end

  # The other half of the same contract: `GET /requete/:exchange_id`, which the
  # tracking page reads the state of its exchange from. Stubbed at the HTTP
  # boundary for the reason above — the point is that the procedure asks the
  # contract, not that a method was called.
  def stub_exchange_state(exchange_id = accepted_body.fetch(:echange), status: 200, **state)
    stub_request(:get, "#{Settings.oots_france_url}/requete/#{exchange_id}")
      .to_return(status:,
        body: { echange: exchange_id, conversation: accepted_body.fetch(:conversation) }.merge(state).to_json,
        headers: { 'Content-Type' => 'application/json' })
  end

  def accepted_body
    { echange: ACCEPTED_EXCHANGE, conversation: ACCEPTED_CONVERSATION, statut: 'pending' }
  end

  # What the last call to the contract carried, read back as the route reads it.
  # The last and not the first: the examples about the conversation of chapter
  # 4.4 make two calls and ask what the second one said.
  def evidence_request_query
    request = WebMock::RequestRegistry.instance.requested_signatures.hash.keys
      .rfind { |signature| signature.uri.path == PATH }

    Rack::Utils.parse_nested_query(request&.uri&.query.to_s)
  end

  # The register the procedure keeps of what it asked for, and which a delivery
  # is placed against. Written as `Demo::RequestEvidence` writes it: both
  # identifiers and nothing else, the evidence arriving later or not at all.
  def registered_request(exchange_id = ACCEPTED_EXCHANGE, **attributes)
    Demo::Request.create!(exchange_id:, conversation_id: ACCEPTED_CONVERSATION, **attributes)
  end
end

RSpec.configure { |config| config.include DemoContractStubs }
