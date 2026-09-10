# The account `db/seeds.rb` creates outside production, and that `rails db:seed`
# put in the *server's* database — the development one, which is not the
# scenario's. It is the only account these scenarios can open.
COMPTE_DEMO = { email: 'admin@example.com', password: 'Administration-2026' }.freeze

Étantdonné('l\'administrateur de démonstration connecté à l\'espace d\'administration') do
  @navigateur = DemoBrowser.new(procedure_url)
  @navigateur.sign_in(COMPTE_DEMO.fetch(:email), COMPTE_DEMO.fetch(:password))

  # Said here rather than left to fail further on: without the server's
  # `db:seed`, every following step would fail on the login page, which names
  # the symptom and not the cause.
  expect(@navigateur.body).not_to include(I18n.t('admin.sessions.new.submit')),
    "Connexion refusée pour #{COMPTE_DEMO.fetch(:email)} : la base du serveur n'a pas été peuplée " \
    'par `rails db:seed`. Voir docs/test_e2e.md.'
end

Quand('l\'administrateur ouvre la démarche de démonstration') do
  @navigateur.visit('/admin/demo')
end

Quand('il clique sur le bouton de la cinématique européenne') do
  @navigateur.start_identification
end

Alors('l\'administrateur arrive sur la page de choix du pays') do
  expect(@navigateur.title).to eq('Choose your country')
end

Quand('l\'administrateur choisit le pays {string}') do |code|
  @navigateur.choose('country', code)
end

Quand('l\'administrateur choisit l\'identité de test {string}') do |cle|
  @navigateur.choose('identity', cle)
end

Quand('l\'administrateur consent à la transmission de ses données') do
  @navigateur.choose('consent', 'yes')
end

# The whole flow, for the scenarios that are about what comes after it.
Quand('l\'administrateur s\'identifie avec l\'identité de test {string}') do |cle|
  @navigateur.visit('/admin/demo')
  @navigateur.start_identification
  @navigateur.choose('country', 'DK')
  @navigateur.choose('identity', cle)
  @navigateur.choose('consent', 'yes')
end

Alors('l\'administrateur arrive sur le formulaire de demande de bourse') do
  expect(@navigateur.current_url).to end_with('/admin/demo/demande')
  expect(@navigateur.title).to eq(I18n.t('admin.demo.grant_requests.show.title'))
end

Alors('le formulaire affiche {string} : {string}') do |intitule, valeur|
  expect(@navigateur.rows).to include(intitule => valeur)
end

# CA4: the attributes of the identity are shown, never typed. The application's
# own fields sit outside those tables, and the assertion is on the tables alone.
Alors('le formulaire affiche l\'identité sans aucun champ de saisie') do
  expect(Nokogiri::HTML(@navigateur.body).css('main table input, main table select, main table textarea'))
    .to be_empty
end

# The `sub` is a pseudonym of FranceConnect+'s own, per service provider:
# showing it beside a missing eIDAS identifier would invite taking it for one.
Alors('le formulaire n\'affiche pas le pseudonyme que FranceConnect+ a donné à l\'usager') do
  expect(@navigateur.body).not_to match(/\h{64}v1/)
end

Alors('le formulaire n\'affiche ni le sexe ni le lieu de naissance') do
  expect(@navigateur.rows.keys).not_to include(
    I18n.t('admin.demo.grant_requests.attributes.gender'),
    I18n.t('admin.demo.grant_requests.attributes.place_of_birth'),
  )
end

Quand('il se déconnecte de l\'espace d\'administration') do
  @navigateur.sign_out
end

Alors('FranceConnect+ le ramène sur la page de déconnexion de la démarche') do
  expect(@navigateur.current_url).to include('/demo/franceconnect/retour_deconnexion')
  expect(@navigateur.title).to eq(I18n.t('france_connect.retour_deconnexion.title'))
  expect(@navigateur.body).to include('session FranceConnect+ est close')
end

Quand('il se reconnecte à l\'espace d\'administration') do
  @navigateur.sign_in(COMPTE_DEMO.fetch(:email), COMPTE_DEMO.fetch(:password))
end

Quand('il ouvre le formulaire de demande de bourse') do
  @navigateur.visit('/admin/demo/demande')
end

Alors('l\'administrateur arrive sur la page d\'accueil de la démarche de démonstration, sans identité') do
  expect(@navigateur.current_url).to end_with('/admin/demo')
end

# Chapter 1 §3.3: the user says explicitly whether the Once-Only Technical
# System is to be used, and nothing leaves without that gesture.
Quand('l\'usager demande que son justificatif soit récupéré') do
  @requetes_avant = ServerAuditEvent.where(event_type: 'request_sent').count
  @navigateur.submit_to('/admin/demo/demande', 'oots' => 'oui')
end

Quand('l\'usager refuse que son justificatif soit récupéré') do
  @requetes_avant = ServerAuditEvent.where(event_type: 'request_sent').count
  @navigateur.submit_to('/admin/demo/demande', 'oots' => 'non')
end

# Requirement 27 of chapter 1 §2. The two values come from the real directories,
# so the scenario asserts that they are there — not what they say, which Brussels
# may rewrite without telling us.
Alors('la page de confirmation affiche le fournisseur et le type de justificatif') do
  lignes = @navigateur.rows

  expect(@navigateur.title).to eq(I18n.t('admin.demo.confirmations.show.title'))
  expect(lignes[I18n.t('admin.demo.confirmations.show.provider')]).to be_present
  expect(lignes[I18n.t('admin.demo.confirmations.show.evidence_type')]).to be_present
end

Quand('l\'usager confirme sa demande') do
  @navigateur.submit_to('/admin/demo/confirmation')
end

# Confirming ends the confirmation page: the request that left is followed on
# the tracking, which is where the answer will appear. The identifier is read
# there, and the state it shows is deliberately not asserted — the exchange is
# already on its way, and what the correspondent has answered by the time this
# page renders is not this scenario's business.
Alors('la page de suivi affiche l\'identifiant de l\'échange ouvert') do
  @exchange_id = @navigateur.rows[I18n.t('admin.demo.trackings.show.exchange')]

  expect(@navigateur.title).to eq(I18n.t('admin.demo.trackings.show.title'))
  expect(@exchange_id).to match(Exchange::UUID)
end

# The procedure is a registered requester like any other, and the log names it
# under its own SIRET — C1's, distinct from C4's.
Alors('le journal des échanges contient le départ de la requête, envoyée par la démarche de démonstration') do
  depart = depart_de_la_requete

  expect(depart.evidence_requester_id).to eq(ENV.fetch('IDENTIFIANT_REQUETEUR_DEMARCHE'))
  expect(depart.procedure_code).to eq('T1')
  expect(depart.country_code).to eq('FR')
end

# The beneficiary token went through the contract, was opened, and its content
# reached the message: the only place the whole chain is visible end to end.
Alors('cette requête contient l\'identité que FranceConnect+ a donnée à la démarche') do
  corps = depart_de_la_requete.regrep_body

  expect(corps).to include('Sørensen', 'Freja Marie', '2001-04-17', 'Substantial')

  # Sur sa forme et non sur sa valeur : le faux FranceConnect+ tire le pseudonyme
  # d'un digest et d'un secret qu'il tire au démarrage, donc une valeur écrite ici
  # ne s'y trouverait jamais, et l'assertion serait vraie quoi qu'il arrive.
  expect(corps).not_to match(/\h{64}v1/)
end

# `R-EDM-REQ-S010` (FATAL) and chapter 4.5.1 §2.7: the slot is true, and the
# `IssueDateTime` does not depart from the instant of the confirmation.
Alors('cette requête déclare que l\'usager a demandé le justificatif') do
  document = Nokogiri::XML(depart_de_la_requete.regrep_body)
  rim = { 'rim' => 'urn:oasis:names:tc:ebxml-regrep:xsd:rim:4.0' }

  expect(document.at_xpath('//rim:Slot[@name="ExplicitRequestGiven"]//rim:Value', rim).text).to eq('true')

  emise = Time.zone.parse(document.at_xpath('//rim:Slot[@name="IssueDateTime"]//rim:Value', rim).text)
  expect(emise).to be_within(1.minute).of(Time.current)
end

Alors('la démarche de démonstration affiche que le justificatif reste à fournir') do
  expect(@navigateur.title).to eq(I18n.t('admin.demo.grant_requests.create.title'))
end

Alors('la France n\'a envoyé aucune requête') do
  expect(ServerAuditEvent.where(event_type: 'request_sent').count).to eq(@requetes_avant)
end

# The log is written by the server, in a database the scenario does not share,
# and `SendToGateway` writes it after submitting to the gateway — hence the wait
# every outcome of these scenarios goes through.
def depart_de_la_requete
  @depart_de_la_requete ||= begin
    patiente_jusqu_a("le journal porte le départ de la requête de l'échange #{@exchange_id}") do
      ServerAuditEvent.exists?(exchange_id: @exchange_id, event_type: 'request_sent')
    end

    ServerAuditEvent.find_by!(exchange_id: @exchange_id, event_type: 'request_sent')
  end
end
