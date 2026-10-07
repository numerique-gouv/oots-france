# The identity of the fake ProConnect whose address is in the domain a
# development machine admits: the administrator of the demonstration.
AGENT_DEMO = 'camille.agent@numerique.gouv.fr'.freeze

Étantdonné('l\'administrateur de démonstration connecté à l\'espace d\'administration') do
  @navigateur = DemoBrowser.new(procedure_url)
  @navigateur.sign_in(AGENT_DEMO)

  # Said here rather than left to fail further on: every following step would
  # otherwise fail on the login page, which names the symptom and not the cause.
  expect(@navigateur.current_url).not_to include('/admin/session/new'),
    "Connexion refusée pour #{AGENT_DEMO} par le faux ProConnect : #{@navigateur.body}"
end

Quand('l\'administrateur ouvre la démarche de démonstration') do
  @navigateur.visit('/admin/demo')
end

# The card of one line, chosen from the screen that offers both: every page of
# the walk after it lives under that line's segment, and the steps below
# compose their addresses on it.
Quand('l\'administrateur choisit la version {string}') do |carte|
  @navigateur.visit('/admin/demo')
  @navigateur.choose_card(carte)
  @ligne = EdmSpecification.from_segment("v#{carte.delete_prefix('OOTS ')}")
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
  @navigateur.visit(adresse_de_la_demarche)
  @navigateur.start_identification('fake')
  @navigateur.choose('country', 'DK')
  @navigateur.choose('identity', cle)
  @navigateur.choose('consent', 'yes')
end

# The heading is the procedure's, as on the home page: the two are one journey.
Alors('l\'administrateur arrive sur la page des justificatifs') do
  expect(@navigateur.current_url).to end_with(adresse_de_la_demarche('documents'))
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
  @navigateur.sign_in(AGENT_DEMO)
end

Quand('il ouvre la page des justificatifs de la démarche') do
  @navigateur.visit(adresse_de_la_demarche('documents'))
end

Alors('l\'administrateur arrive sur l\'écran du choix de la version, sans identité') do
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

  expect(@navigateur.current_url).to end_with(adresse_de_la_demarche('documents'))
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
  @navigateur.submit_to(adresse_de_la_demarche('demande'))
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
# The console's page of the exchange the click opened, which says the line it
# was conducted in.
Alors('la fiche de cet échange affiche la version {string}') do |version|
  @navigateur.visit("/admin/journal/exchanges/#{depart_de_la_requete.exchange_id}")

  expect(@navigateur.rows).to include(I18n.t('admin.journal.exchanges.attributes.specification') => version)
end

# Chapter 4.9 §5: the zone becomes the departure page once the demonstration
# has confirmed the preview the correspondent asked for, which it does the first
# time it reads that state. The correspondent answers on another connection, so
# the page is asked again until it presents the link.
#
# The preview space is France's own, on the same host: the steps of
# `preview_steps.rb` walk it through the same browser, which keeps the
# operator's session for the way back.
Quand('l\'usager suit le lien que la page des justificatifs lui présente vers l\'espace de prévisualisation') do
  patiente_jusqu_a('la page des justificatifs présente le lien vers l\'espace de prévisualisation') do
    @navigateur.visit(adresse_de_la_demarche('documents'))
    lien_de_depart.present?
  end

  @lien_de_depart = lien_de_depart
  @space_browser = @navigateur
  @navigateur.follow_address(@lien_de_depart)
end

# Chapter 4.9 v1.2.3 §5: « Add the return address, in encoded form, as a value
# of the "returnurl" query parameter », with `returnmethod`.
Alors('ce lien contient l\'adresse de retour dans {string} et sa méthode dans {string}') do |adresse, methode|
  query = Rack::Utils.parse_query(URI.parse(@lien_de_depart).query)

  expect(query[adresse]).to start_with("#{oots_france_url}/retour/")
  expect(query[methode]).to eq('GET')
end

# The way back is known once the second request has reached the space, which
# runs in parallel with the visit (chapter 4.9 §2 step 12): the space is asked
# again until it sends the user back to the procedure.
Quand('l\'usager est ramené à sa démarche') do
  patiente_jusqu_a('l\'espace de prévisualisation ramène l\'usager à sa démarche') do
    next true if de_retour_sur_la_demarche?

    @navigateur.follow_address(@lien_de_depart)
    de_retour_sur_la_demarche?
  end
end

Alors('l\'usager arrive sur la page des justificatifs, qui reçoit l\'échange et la conversation') do
  arrivee = URI.parse(@navigateur.current_url)

  expect(arrivee.path).to eq(adresse_de_la_demarche('documents'))
  expect(Rack::Utils.parse_query(arrivee.query))
    .to include('echange' => depart_de_la_requete.exchange_id, 'conversation' => be_present)
end

# The document comes back on another connection: the page is asked again, as
# the zone asks again, until it says so.
Alors('la page des justificatifs affiche {string}') do |texte|
  attend_sur_la_page_des_justificatifs(texte)
end

Alors('la page des justificatifs affiche que l\'usager a choisi de ne pas utiliser le document') do
  attend_sur_la_page_des_justificatifs(I18n.t('components.demo_request_zone.declined_title'))
end

def attend_sur_la_page_des_justificatifs(texte)
  patiente_jusqu_a("la page des justificatifs affiche « #{texte} »") do
    @navigateur.visit(adresse_de_la_demarche('documents'))
    @navigateur.body.include?(texte)
  end
end

def lien_de_depart = @navigateur.links('.demo-request__preview a.fr-btn').first

def de_retour_sur_la_demarche? = URI.parse(@navigateur.current_url).path == adresse_de_la_demarche('documents')

# An address of the walk, under the segment of the line the scenario chose.
def adresse_de_la_demarche(page = nil)
  raise 'Aucune version choisie : le pas « choisit la version » précède celui-ci.' if @ligne.nil?

  ['/admin/demo', @ligne.segment, page].compact.join('/')
end

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
