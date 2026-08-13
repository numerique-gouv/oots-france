# The gateway dispatcher pushes notifications on its own schedule, and the AS4
# round trip crosses two queues. Nothing here is instantaneous, so every
# assertion about an outcome polls until it holds or gives up.
DELAI_MAX = 90
INTERVALLE = 1

Étantdonné('une démarche française déclarée dans l\'annuaire') do
  @requester_id = ENV.fetch('IDENTIFIANT_REQUETEUR_TEST', '00000000000002')
  @requester = Directories::EvidenceRequesters.new.find(@requester_id)

  # The port comes from the directory: moving the fake requester is a matter of
  # changing the directory, not of touching this test.
  @fake_requester = FakeRequester.new.start(URI.parse(@requester.url).port)
end

Étantdonné('les annuaires centraux désignent la passerelle locale') do
  @fake_common_services = FakeCommonServices.new.start
end

Étantdonné('cette démarche publie ses clés de signature') do
  expect(Faraday.get("#{@requester.url}/auth/cles_publiques").status).to eq(200)
end

Quand('la démarche demande un justificatif pour la procédure {string}') do |procedure|
  token = @fake_requester.beneficiary_token(oots_france_url, BENEFICIAIRE)

  @response = Faraday.get("#{oots_france_url}/requete/pieceJustificative", {
    codeDemarche: procedure, codePays: 'FR', idRequeteur: @requester_id, beneficiaire: token,
  })
end

Alors('la démarche reçoit tout de suite l\'identifiant de l\'échange') do
  expect(@response.status).to eq(202)

  @conversation_id = JSON.parse(@response.body)['conversation']
  expect(@conversation_id).to be_present
end

Alors('le justificatif finit par être transmis à la démarche') do
  patiente_jusqu_a('le justificatif soit transmis') { @fake_requester.received_evidence.present? }
end

Alors('le document reçu est celui que le fournisseur détient') do
  attendu = Rails.root.join('assets/drapeau.pdf').binread

  expect(@fake_requester.received_evidence.b).to eq(attendu.b)
end

Alors('la conversation finit par porter le code d\'erreur {string}') do |code|
  # Read through the application, not from the database: the scenarios run in a
  # different Rails environment from the server, and therefore against a
  # different database.
  patiente_jusqu_a("l'échange porte #{code}") do
    JSON.parse(Faraday.get("#{oots_france_url}/requete/#{@conversation_id}").body)['codeErreur'] == code
  end
end

Alors('aucun justificatif n\'est transmis à la démarche') do
  expect(@fake_requester.received_evidence).to be_nil
end

def oots_france_url = ENV.fetch('URL_OOTS_FRANCE')

BENEFICIAIRE = { 'nomUsage' => 'Dupont', 'prenom' => 'Sophie', 'dateNaissance' => '1965-11-25' }.freeze

def patiente_jusqu_a(description)
  limite = Time.current + DELAI_MAX

  loop do
    return if yield
    raise "Toujours pas vrai après #{DELAI_MAX} s : #{description}" if Time.current > limite

    sleep INTERVALLE
  end
end
