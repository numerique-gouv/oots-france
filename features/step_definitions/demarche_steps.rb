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

Quand('il choisit le bouton du faux FranceConnect+') do
  @navigateur.start_identification('fake')
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
  @navigateur.start_identification('fake')
  @navigateur.choose('country', 'DK')
  @navigateur.choose('identity', cle)
  @navigateur.choose('consent', 'yes')
end

# The heading is the procedure's, as on the home page: the two are one journey.
Alors('l\'administrateur arrive sur la page des justificatifs') do
  expect(@navigateur.current_url).to end_with('/admin/demo/documents')
  expect(@navigateur.title).to include(ProcedureCode::STUDY_FINANCING)
end

Alors('la page affiche {string} : {string}') do |intitule, valeur|
  expect(@navigateur.rows).to include(intitule => valeur)
end

# The level wears a badge and no row, being the whole of what the authentication
# adds to the identity above it.
Alors('la page affiche le niveau de garantie {string}') do |niveau|
  expect(@navigateur.badges).to include(niveau)
end

# CA4: the attributes of the identity are shown, never typed. Scoped to the
# card that holds them: the page carries a form of its own, the one the button
# submits.
Alors('la page affiche l\'identité sans aucun champ de saisie') do
  expect(Nokogiri::HTML(@navigateur.body).css('.identity-card input, .identity-card select, .identity-card textarea'))
    .to be_empty
end

# The `sub` is a pseudonym of FranceConnect+'s own, per service provider:
# showing it beside a missing eIDAS identifier would invite taking it for one.
Alors('la page n\'affiche pas le pseudonyme que FranceConnect+ a donné à l\'usager') do
  expect(@navigateur.body).not_to match(/\h{64}v1/)
end

Alors('la page n\'affiche ni le sexe ni le lieu de naissance') do
  expect(@navigateur.rows.keys).not_to include(
    I18n.t('components.demo_identity_card.attributes.gender'),
    I18n.t('components.demo_identity_card.attributes.place_of_birth'),
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

Quand('il ouvre la page des justificatifs de la démarche') do
  @navigateur.visit('/admin/demo/documents')
end

Alors('l\'administrateur arrive sur la page d\'accueil de la démarche de démonstration, sans identité') do
  expect(@navigateur.current_url).to end_with('/admin/demo')
end

# Requirement 27 of chapter 1 §2. The two values come from the real directories,
# so the scenario asserts that they are there — not what they say, which Brussels
# may rewrite without telling us. They are named on the card that carries the
# button, in the one sentence that stands between the rule and it, and each
# wears the mark of what the directories publish.
Alors('la page des justificatifs affiche le fournisseur et le type de justificatif') do
  nommes = Nokogiri::HTML(@navigateur.body)
    .css('.requirement-card__actions .directory-value').map { |valeur| valeur.text.strip }

  expect(@navigateur.current_url).to end_with('/admin/demo/documents')
  expect(nommes.size).to eq(2)
  expect(nommes).not_to include('')
end

# Chapter 1 §3.3: this click is where the user says explicitly that the
# Once-Only Technical System is to be used, and nothing leaves without it.
# The mark is taken before the click and not after: the log is the server's and
# a previous run leaves its own events in it, so what this scenario opened is
# what was written past this point.
Quand('l\'usager confirme sa demande') do
  @journal_avant = ServerAuditEvent.maximum(:id).to_i
  @navigateur.submit_to('/admin/demo/demande')
end

# The click answers with the zone it was made in, saying the request is out. The
# state is deliberately not asserted beyond that — the exchange is already on
# its way, and what the correspondent has answered by the time this renders is
# not this scenario's business.
#
# The zone is recognised by what it declares of itself and not by its wording:
# the sentences around it name the document that was asked for, which the real
# directories publish and Brussels may rewrite without telling us.
Alors('la page des justificatifs affiche que la demande de l\'usager est en cours') do
  zone = Nokogiri::HTML(@navigateur.body).at_css('.demo-request__body')

  expect(zone).to be_present
  expect(zone['data-polling']).to eq('true')
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

# The log is written by the server, in a database the scenario does not share,
# and `SendToGateway` writes it after submitting to the gateway — hence the wait
# every outcome of these scenarios goes through.
# The departure this scenario opened, found by the requester it was sent under
# rather than by an identifier read off a screen: the procedure keeps its
# exchange in its own register, which no route publishes, and the log is where
# the scenario can see it.
def depart_de_la_requete
  @depart_de_la_requete ||= begin
    patiente_jusqu_a('le journal porte le départ de la requête de la démarche de démonstration') do
      departs_de_la_demarche.exists?
    end

    departs_de_la_demarche.last.tap { |depart| @exchange_id = depart.exchange_id }
  end
end

def departs_de_la_demarche
  ServerAuditEvent
    .where(event_type: 'request_sent', evidence_requester_id: ENV.fetch('IDENTIFIANT_REQUETEUR_DEMARCHE'))
    .where(id: (@journal_avant.to_i + 1)..)
    .order(:id)
end
