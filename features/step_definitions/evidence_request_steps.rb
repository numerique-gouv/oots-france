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
  @response = demande(procedure)
end

# Chapter 4.4: the conversation identifies the user and their session, and the
# portal is the one that knows two requests are the same person's. It says so by
# naming the same conversation twice.
#
# On a procedure no evidence is served for, deliberately: what is asserted here
# is what the two requests are given at once, and a scenario that also set a
# delivery going would hand its PDF to the next scenario's requester, the two
# listening on one port.
Quand('la démarche demande deux justificatifs pour le même usager') do
  @premier = etat_de(demande('T3', conversation: SESSION_USAGER))
  @second = etat_de(demande('T3', conversation: SESSION_USAGER))
end

Alors('les deux requêtes portent la même conversation et deux échanges distincts') do
  expect(@premier['conversation']).to eq(SESSION_USAGER)
  expect(@second['conversation']).to eq(SESSION_USAGER)
  expect(@second['echange']).not_to eq(@premier['echange'])
end

Alors('la démarche reçoit tout de suite l\'identifiant de l\'échange') do
  expect(@response.status).to eq(202)

  @exchange_id = JSON.parse(@response.body)['echange']
  expect(@exchange_id).to be_present
end

Alors('le justificatif finit par être transmis à la démarche') do
  patiente_jusqu_a('le justificatif soit transmis') { @fake_requester.received_evidence.present? }
end

Alors('le document reçu est celui que le fournisseur détient') do
  attendu = Rails.root.join('assets/drapeau.pdf').binread

  expect(@fake_requester.received_evidence.b).to eq(attendu.b)
end

Alors('l\'échange finit par porter le code d\'erreur {string}') do |code|
  # Read through the application, not from the database: the scenarios run in a
  # different Rails environment from the server, and therefore against a
  # different database.
  patiente_jusqu_a("l'échange porte #{code}") do
    JSON.parse(Faraday.get("#{oots_france_url}/requete/#{@exchange_id}").body)['codeErreur'] == code
  end
end

Alors('l\'échange finit par porter l\'état {string}') do |statut|
  patiente_jusqu_a("l'échange porte l'état #{statut}") { etat_de_l_echange['statut'] == statut }
end

# Chapter 4.5.2: the announcement is what sends the procedure portal back with a
# new Evidence Request « at the time of availability », so the date has to reach
# the caller and not merely the console.
Alors('la démarche apprend la date à laquelle le justificatif sera disponible') do
  annoncee = etat_de_l_echange['dateDisponibilite']

  expect(annoncee).to be_present
  expect(Time.zone.parse(annoncee)).to be > Time.current
end

Alors('aucun justificatif n\'est transmis à la démarche') do
  expect(@fake_requester.received_evidence).to be_nil
end

# The log is the only claim of these scenarios that cannot be read through the
# application: chapter 4.8 asks for a trace, and the trace is exposed by no
# route on purpose — it carries personal data.
Alors('le journal porte l\'échange entier, du départ de la requête à la remise') do
  patiente_jusqu_a('le journal porte la remise') { journal.exists?(event_type: 'evidence_delivered') }

  # France answers itself over the single gateway of the example PMode, so one
  # exchange identifier carries both halves of it.
  expect(journal.pluck(:event_type)).to include(
    'request_sent', 'request_received', 'response_sent', 'response_received', 'evidence_delivered',
  )

  depart = journal.find_by!(event_type: 'request_sent')
  expect(depart.message_id).to be_present
  expect(depart.evidence_subject_key).to eq('dupont|sophie|1965-11-25')

  # The two halves must name the request identically, or nothing correlates a
  # response to the request that caused it.
  expect(journal.pluck(:request_id).compact.uniq).to contain_exactly(depart.request_id)

  remise = journal.find_by!(event_type: 'evidence_delivered')
  expect(remise.evidence_digest).to eq(Digest::SHA256.hexdigest(Rails.root.join('assets/drapeau.pdf').binread))
end

Alors('le journal porte l\'annonce du correspondant') do
  patiente_jusqu_a("le journal porte l'annonce") { journal.exists?(event_type: 'response_received') }

  # A response did go out and did come back, and it carried no document: both
  # halves say so by the absence of a fingerprint.
  expect(journal.pluck(:event_type)).to include('request_sent', 'request_received', 'response_sent',
    'response_received')
  expect(journal.pluck(:evidence_digest).compact).to be_empty
end

Alors('le journal porte le refus du correspondant') do
  patiente_jusqu_a('le journal porte le refus') { journal.exists?(event_type: 'error_received') }

  expect(journal.find_by!(event_type: 'error_received').edm_error_code).to eq('EDM:ERR:0004')
end

def journal = ServerAuditEvent.where(exchange_id: @exchange_id)

# One user's session, named by the portal rather than left to the application:
# `R-EDM-ebMS-017` wants a UUID, and the same one twice is what makes the two
# requests one conversation.
SESSION_USAGER = '5fe50e16-d6b8-4005-b5ec-0ab097f34448'.freeze

def demande(procedure, conversation: nil)
  token = @fake_requester.beneficiary_token(oots_france_url, BENEFICIAIRE)

  Faraday.get("#{oots_france_url}/requete/pieceJustificative", {
    codeDemarche: procedure, codePays: 'FR', idRequeteur: @requester_id, beneficiaire: token,
    idConversation: conversation,
  }.compact)
end

def etat_de(response)
  expect(response.status).to eq(202)

  JSON.parse(response.body)
end

def etat_de_l_echange
  JSON.parse(Faraday.get("#{oots_france_url}/requete/#{@exchange_id}").body)
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
