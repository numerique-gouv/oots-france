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

  # The journey and the requirement a row of the register carries when the
  # example is about what happens to the document rather than about which zone
  # follows which request.
  REGISTERED_JOURNEY = 'cccccccc-0000-4000-8000-000000000001'.freeze
  REGISTERED_REQUIREMENT = '00000000-0000-0000-0000-000000000000'.freeze

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

  # The address the Semantic Repository publishes a requirement under, which is
  # what travels in `idExigence`.
  def requirement_uri(uuid) = "https://sr.acc.oots.tech.ec.europa.eu/requirements/#{uuid}"

  # The contract answering one requirement in particular. Registered after the
  # general double so that WebMock prefers it: a different exchange per
  # requirement is what makes two clicks two exchanges rather than one read
  # twice.
  def stub_evidence_request_for(uuid, exchange_id)
    stub_request(:get, "#{Settings.oots_france_url}#{PATH}")
      .with(query: hash_including('idExigence' => requirement_uri(uuid)))
      .to_return(status: 202, headers: { 'Content-Type' => 'application/json' },
        body: { echange: exchange_id, conversation: ACCEPTED_CONVERSATION, statut: 'pending' }.to_json)
  end

  # The other half of the same contract: `GET /requete/:exchange_id`, which the
  # zone of the documents page reads the state of its exchange from. Stubbed at the HTTP
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

  # The demands the contract has received, in the order they were made. Read off
  # WebMock's own registry: a scenario played in a browser cannot reach for
  # `a_request(...)` and `have_been_made`, `hash_including` being both WebMock's
  # and rspec-mocks' where the two share a World.
  def contract_demands
    WebMock::RequestRegistry.instance.requested_signatures.hash.keys
      .select { |signature| signature.uri.path == PATH }
  end

  # The conversation each call to the contract named, in the order they were
  # made. Read off the demands rather than compared to a constant: the journey
  # mints the conversation, so what matters of two clicks is whether they named
  # the same one, never which value it took.
  def conversations_asked
    contract_demands.map { |demand| Rack::Utils.parse_nested_query(demand.uri.query.to_s)['idConversation'] }
  end

  # What the last call to the contract carried, read back as the route reads it.
  # The last and not the first: the examples about the conversation of chapter
  # 4.4 make two calls and ask what the second one said.
  def evidence_request_query
    Rack::Utils.parse_nested_query(contract_demands.last&.uri&.query.to_s)
  end

  # The register the procedure keeps of what it asked for, and which a delivery
  # is placed against. Written as `Demo::RequestEvidence` writes it: the
  # identifiers of the exchange, the journey that clicked and the requirement it
  # clicked under, the evidence arriving later or not at all.
  #
  # The journey stands for a session no delivery ever meets — a document is
  # placed on the exchange it names, and the register is what says that exchange
  # is one of the known.
  def registered_request(exchange_id = ACCEPTED_EXCHANGE, **attributes)
    Demo::Request.create!(exchange_id:, conversation_id: ACCEPTED_CONVERSATION,
      journey_id: REGISTERED_JOURNEY, requirement_uuid: REGISTERED_REQUIREMENT, **attributes)
  end
end
