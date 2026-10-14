# The address of the zone: the button posts to it, and the waiting re-asks it.
# Both are intercepted, which is the whole reason the pattern names no method —
# one scenario is about a click whose own answer is lost being retried as an
# interrogation, and telling the two apart is what it has to prove.
ZONE_ADDRESS = '*/admin/demo/v2.0/T1/demande*'.freeze

# The address a card's list posts the chosen country to.
COUNTRY_ADDRESS = '*/admin/demo/v2.0/T1/pays*'.freeze

# The address a card's list posts the chosen evidence type to, in either line.
EVIDENCE_TYPE_ADDRESS = '*/T1/type_justificatif*'.freeze

# The two evidence types Austria publishes for « (TEST) Test Requirement », in
# `eb_evidence_types_at`, by the title the list shows: what the contract
# receives is the identifier, and a scenario names the document.
AUSTRIAN_TYPES = {
  'Test Evidence Austria (AT)' => 'cb10c17a-8d2a-40af-bb77-e797182280bf',
  'Austrian Test Evidence Type without Reauthentication' => '198ab7cc-8571-451d-9727-4be8ed221951',
}.freeze

# The card of one requirement, which the list, the country line and the
# sentence of a choice left unanswered all belong to.
CARD = '.requirement-card'.freeze

# The documents page, in either line of the walk.
DOCUMENTS_PAGE = %r{\A/admin/demo/v\d\.\d/T1/documents\z}

# Where a card names its country: its list, or the box of a card following a
# request, which offers none.
NAMED_COUNTRY = 'select[name=pays] option:checked, .fr-card__desc .country-tag'.freeze

# What the foot of a card says under the questions of the Data Service
# Directory: the document and its provider, or the refusal standing in for them.
RESOLUTION = '.requirement-card__actions [data-demo-card-target="resolution"]'.freeze

# What an answer replaces, and what says which outcome is on screen.
BODY = '.demo-request__body'.freeze

# Set on the waiting by the scenario and read back after an answer: `innerHTML`
# replaced takes it with it, a `splice` that abstains leaves it. A `data-`
# nothing in the application reads, and not the `data-outcome` the controller
# compares.
MARK = 'the-same-waiting'.freeze

# Set on the window when the page is arrived at, and read back to say a zone was
# spliced into rather than navigated away from: a reload loses it.
PAGE_MARK = 'not-reloaded'.freeze

# The element an answer never replaces — it carries the controller and the
# announced region — and the one the zone's contents live inside.
ZONE = '.demo-request'.freeze

# Set on that element when the page is arrived at, and read back after an answer
# has changed the zone: `innerHTML` replaced leaves the element, `outerHTML`
# would take it away along with what announces it.
ZONE_MARK = 'the-same-zone'.freeze

# What the zone leaves between two interrogations. Waited past, to say that no
# other one went out — the absence of a request cannot be waited *for*.
INTERVAL = 2

# How many answers in a row the zone may fail to get before it says so, and so
# how long giving up takes: three interrogations an interval apart, which is
# longer than `Capybara.default_max_wait_time` and has to be said here.
ATTEMPTS = 3
GIVING_UP = INTERVAL * (ATTEMPTS + 2)

# The document the correspondent's delivery files against the exchange, which is
# what settles the outcome whatever the contract still says.
EVIDENCE = "%PDF-1.4\ndrapeau".b

# The two requirements `eb_requirements_t1_fr` publishes, in the order the page
# renders their cards — which is how a scenario names the one it clicks, the
# doubled directories answering both with the same evidence type and the same
# provider.
REQUIREMENTS = { 'première' => 'ffffffff-ffff-ffff-ffff-ffffffffffff',
                 'seconde' => '2d21a531-d30e-4e30-9e5e-b53d6aedb30b' }.freeze

# The requirements the catalogue offers to add a card for, by the name the list
# shows: a card is found on the page by the anchor its requirement gives it.
CATALOGUE = { '(TEST) Test Requirement 2' => 'ffffffff-ffff-ffff-ffff-ffffffffffff' }.freeze

# The exchange the contract opens for the second requirement, so that two clicks
# are two exchanges rather than one read twice.
SECOND_EXCHANGE = 'aaaaaaaa-0000-4000-8000-000000000002'.freeze

Étantdonné('les annuaires et le contrat de la démarche doublés') do
  # First of all, and not by taste: it is what pins `Settings.oots_france_url`,
  # the root every double of the contract below is mounted on.
  stub_browser_france_connect

  stub_code_list
  stub_directory_resolution
  stub_directory('eb', 'requirements-by-procedure', 'eb_requirements_fr')
  stub_directory('eb', 'evidence-types-by-requirement', 'eb_evidence_types_fi')
  stub_directory('dsd', 'dataservices-by-evidencetype', 'dsd_data_services_fi')
  stub_oots_france_public_keys
  stub_evidence_request
  stub_exchange_state
end

# The whole European flow as the browser walks it: the departure is clicked, the
# authorization endpoint sends the browser back, and the return is accepted on a
# `state` and a `nonce` this scenario never wrote.
Étantdonné("l'usager identifié sur la page des justificatifs") do
  visit admin_demo_root_path
  click_link 'OOTS 2.0'
  find("a[href='#{admin_demo_home_path(version: 'v2.0', procedure: 'T1')}']").click
  sign_in_with('fake')

  expect(page).to have_button(press_label)
  mark_the_page
end

# A new identification, in a journey opened under the other line: the Austrian
# access point announces `oots-edm:v1.2` and not `v2.0`.
Étantdonné("l'usager identifié sur la page des justificatifs d'un parcours en 1.2") do
  identify_in_line_1_2
end

Quand("l'usager s'identifie de nouveau, dans un parcours en 1.2") do
  identify_in_line_1_2
end

# Doubled after the `Contexte`, so that WebMock prefers these for Austria, and
# with Austria named in the code list as the scenarios name it — the page is
# asked for again, so that its list of countries carries that name.
Étantdonné("l'Autriche publiant deux types de justificatif pour l'exigence de la carte") do
  stub_code_list(country_names: CodeListStubs::DEFAULT_COUNTRY_NAMES.merge('AT' => 'Austria'))
  stub_directory('eb', 'evidence-types-by-requirement', 'eb_evidence_types_at', country: 'AT')
  AUSTRIAN_TYPES.each_value do |uuid|
    stub_directory('dsd', 'dataservices-by-evidencetype', "dsd_data_services_at_#{uuid[0, 8]}",
      evidence_type: austrian_type_id(uuid))
  end

  visit current_path
  mark_the_page
end

# What the Data Service Directory answers a country with no service for that
# type: the `DSD:ERR:0001` captured for France, whose signature covers the body
# alone and so holds for any query.
Étantdonné('aucun fournisseur publié en Autriche pour {string}') do |title|
  stub_directory('dsd', 'dataservices-by-evidencetype', 'dsd_aucun_service_fr',
    evidence_type: austrian_type_id(AUSTRIAN_TYPES.fetch(title)))
end

Étantdonné('le choix du type répondu en {string} sans l\'en-tête "Deferred-Fragment", puis coupé, devant le navigateur') do |status|
  evidence_type_requests.answer(status: status.to_i, body: BAD_GATEWAY_PAGE).cut
end

Quand('le choix suivant du type est coupé devant le navigateur') do
  evidence_type_requests.cut
end

Étantdonné('le choix du type répondu en {string} sans l\'en-tête "Deferred-Fragment" devant le navigateur') do |status|
  evidence_type_requests.answer(status: status.to_i, body: '')
end

Étantdonné('la soumission de la demande retenue devant le navigateur') do
  zone_requests.hold
end

# The procedure rests on two requirements here where the `Contexte` doubles one,
# and the page is asked for again so that both cards stand on it. The journey
# the sign-in opened is untouched: what a card is clicked under is read from it,
# never written by a click.
Étantdonné('les deux exigences de la démarche affichées') do
  stub_directory('eb', 'requirements-by-procedure', 'eb_requirements_t1_fr')
  stub_evidence_request_for(REQUIREMENTS.fetch('seconde'), SECOND_EXCHANGE)
  stub_exchange_state(SECOND_EXCHANGE, statut: 'pending')

  visit admin_demo_documents_path(version: 'v2.0', procedure: 'T1')

  expect(page).to have_css(ZONE, count: REQUIREMENTS.size)
  mark_the_page
end

# An answer this application never wrote, then none at all: the two ways a
# choice gets nothing the card can splice.
Étantdonné('le choix du pays répondu en {string} sans l\'en-tête "Deferred-Fragment", puis coupé, devant le navigateur') do |status|
  country_requests.answer(status: status.to_i, body: BAD_GATEWAY_PAGE).cut
end

# Planned after the choices already made: the double treats requests in order.
Quand('le choix suivant du pays est coupé devant le navigateur') do
  country_requests.cut
end

Étantdonné('le choix du pays répondu en {string} sans l\'en-tête "Deferred-Fragment" devant le navigateur') do |status|
  country_requests.answer(status: status.to_i, body: '')
end

# Both clicks held before either is answered: the second leaves while the first
# is still out, which is the race itself.
Étantdonné('les soumissions des deux cartes retenues devant le navigateur') do
  zone_requests.hold.hold
end

Étantdonné('la soumission de la demande et les deux requêtes suivantes coupées devant le navigateur') do
  zone_requests.cut.cut.cut
end

# Clicked and answered before anything is planned for what follows: the zone
# schedules its first interrogation on that answer, so a treatment armed any
# earlier would meet the submission instead.
Étantdonné('une demande en cours') do
  click_button press_label

  expect(page).to have_text(I18n.t('components.demo_request_zone.loading'))
  wait_until_registered
  mark_the_waiting
end

Étantdonné('la première interrogation laissée passer, la deuxième retenue devant le navigateur') do
  zone_requests.pass.hold
end

Étantdonné('la première interrogation coupée, la deuxième répondue sans l\'en-tête "Deferred-Fragment" devant le navigateur') do
  zone_requests.cut.answer(status: 502, body: BAD_GATEWAY_PAGE)
end

Étantdonné('les trois interrogations suivantes coupées devant le navigateur') do
  zone_requests.cut.cut.cut
end

Étantdonné('une interrogation retenue devant le navigateur') do
  zone_requests.hold
end

Quand("l'usager clique sur {string}") do |label|
  click_button label
end

Quand("l'usager clique sur le bouton de la {word} carte") do |rank|
  within(card_zone(rank)) { click_button press_label }
end

# The option is named as the list shows it, flag aside: the flag is an emoji the
# label begins with, and a scenario spells the country, not its picture.
Quand("l'usager choisit {string} dans la liste des pays de la carte") do |country|
  label = I18n.t('components.demo_requirement_card.country_label')

  find_field(label).find('option', text: country).select_option
end

Quand("l'usager choisit {string} dans la liste des pays de la {word} carte") do |country, rank|
  label = I18n.t('components.demo_requirement_card.country_label')

  within(card(rank)) { find_field(label).find('option', text: country).select_option }
end

Quand("l'usager choisit {string} dans la liste des types de la carte") do |title|
  find_field(evidence_type_label).find('option', exact_text: title).select_option
end

Quand('la soumission retenue est libérée') do
  zone_requests.release
end

# In the order they were clicked, which the double holds them in: the second
# answer is then the one that comes back last.
Quand("les deux soumissions retenues sont libérées dans l'ordre des clics") do
  2.times { zone_requests.release }
end

Quand("l'interrogation retenue est libérée") do
  zone_requests.release
end

# Blocks until the browser has asked, which is what makes the next assertion
# about a request that has actually gone out rather than one that may yet.
Quand('la zone interroge son adresse') do
  zone_requests.held
end

Quand('deux interrogations de suite n\'obtiennent aucune réponse exploitable') do
  wait_until_seen(2)
end

Quand('le justificatif est remis') do
  Demo::Request.sole.receive_evidence!(EVIDENCE)
end

Quand("l'usager recharge la page des justificatifs") do
  page.refresh
  mark_the_page
end

Quand('le compte de l\'administrateur est supprimé') do
  @administrator.destroy!
end

# The one thing the server cannot say, so the one the browser says of itself.
# Waited for rather than asserted: three interrogations two seconds apart is
# what precedes it.
Quand('la zone renonce à joindre le service') do
  # `normalize_ws`: the wording places a link mid-sentence, so the rendering
  # breaks it over three lines where the translation has one.
  expect(page).to have_text(disconnected_sentence, wait: GIVING_UP, normalize_ws: true)
end

Quand("l'usager suit le lien {string}") do |label|
  click_link label
end

Alors("la zone annonce qu'elle attend") do
  expect(page).to have_text(I18n.t('components.demo_request_zone.loading'))
  expect(page).to have_css("#{BODY}[data-outcome='pending']", visible: :all)
  mark_the_waiting
end

Alors("la zone de la {word} carte annonce qu'elle attend") do |rank|
  within(card_zone(rank)) do
    expect(page).to have_text(I18n.t('components.demo_request_zone.loading'))
    expect(page).to have_css("#{BODY}[data-outcome='pending']", visible: :all)
  end
end

# Each on the request its own click opened, whichever answer came back last:
# what the page renders a zone on is read from the register, under the journey
# and the requirement, and a click writes nothing a neighbour could overwrite.
#
# The register is waited on first, and not out of caution: the zone announces
# its waiting the instant the button is clicked, before any answer has come
# back, so the screen alone would let this step pass over a submission still in
# flight — and the reload that follows would then render on one request.
Alors("les deux zones annoncent qu'elles attendent") do
  wait_until_registered(REQUIREMENTS.size)

  expect(page).to have_css("#{BODY}[data-outcome='pending']", count: REQUIREMENTS.size, visible: :all)
  expect(page).to have_text(I18n.t('components.demo_request_zone.loading'), count: REQUIREMENTS.size)
end

Alors('la zone annonce toujours la même attente') do
  expect(page).to have_text(I18n.t('components.demo_request_zone.loading'))
  expect(page).to have_css("#{BODY}[data-scenario-mark='#{MARK}']", visible: :all)
end

# Neither of its two labels: asking again after a refusal is the same button
# under another word, and giving up offers neither.
Alors('la page n\'affiche aucun bouton de demande') do
  expect(page).to have_no_button(I18n.t('components.demo_request_zone.submit'))
  expect(page).to have_no_button(I18n.t('components.demo_request_zone.retry'))
end

Alors('la page affiche le bouton {string}') do |label|
  expect(page).to have_button(label)
end

Alors('la page affiche le lien {string}') do |label|
  expect(page).to have_link(label)
end

Alors('la page des justificatifs est toujours affichée') do
  expect(page).to have_current_path(admin_demo_documents_path(version: 'v2.0', procedure: 'T1'))
end

# Chapter-free and structural: the element that holds the announced region is
# the one an answer must not replace, and a zone rebuilt whole would lose it
# along with the controller that keeps asking.
Alors("la zone n'a pas été remplacée, seulement son contenu") do
  expect(page).to have_css("#{ZONE}[data-scenario-zone='#{ZONE_MARK}']", visible: :all)
end

Alors("la page des justificatifs n'a pas été rechargée") do
  expect(page).to have_current_path(DOCUMENTS_PAGE)
  expect(page.evaluate_script('window.pageMark')).to eq(PAGE_MARK)
end

Alors("le contrat n'a reçu aucune demande") do
  expect(contract_demands).to be_empty
end

# Waited for: releasing the submission hands it on asynchronously, so the
# demand reaches the contract after this step has begun.
Alors('le contrat a reçu la demande') do
  wait_until('Le contrat n\'a reçu aucune demande.') { contract_demands.any? }
end

# In its list of countries, or, on a card that follows a request and offers
# none, in the box that stands in its place.
Alors('la carte nomme le pays {string}') do |country|
  expect(find(CARD)).to have_css(NAMED_COUNTRY, text: country)
end

Alors('la {word} carte nomme le pays {string}') do |rank, country|
  expect(card(rank)).to have_css(NAMED_COUNTRY, text: country)
end

Alors("la carte n'offre pas de liste des pays") do
  expect(find(CARD)).to have_no_field(I18n.t('components.demo_requirement_card.country_label'))
end

# The two names requirement 27 of chapter 1 §2 has shown before any request,
# each marked as published by the directories.
Alors('la carte nomme le type {string} et le fournisseur {string}') do |type, provider|
  named = "#{RESOLUTION} .directory-value"

  expect(find(CARD)).to have_css("#{named}:first-of-type", text: /\A#{Regexp.escape(type)}/)
  expect(find(CARD)).to have_css(named, text: /\A#{Regexp.escape(provider)}/)
end

Alors('la carte ne nomme aucun fournisseur') do
  expect(find(CARD)).to have_no_css("#{RESOLUTION} .directory-value")
end

Alors('la liste des types de la carte affiche {string}') do |title|
  expect(find_field(evidence_type_label)).to have_css('option:checked', exact_text: title)
end

Alors('la liste des types de la carte offre {string} puis {string}') do |first, second|
  offered = find_field(evidence_type_label).all('option').map(&:text).reject { |text| text == evidence_type_prompt }

  expect(offered).to eq([first, second])
end

Alors("la liste des types de la carte n'offre plus {string}") do |title|
  expect(find_field(evidence_type_label)).to have_no_css('option', exact_text: title)
end

Alors("la carte n'offre pas de liste des types") do
  expect(find(CARD)).to have_no_field(evidence_type_label)
end

Alors('le contrat a reçu la demande pour le type {string}') do |title|
  asked = austrian_type_id(AUSTRIAN_TYPES.fetch(title))

  wait_until("Le contrat n'a reçu aucune demande pour le type #{title}.") do
    contract_demands.any? { |demand| Rack::Utils.parse_nested_query(demand.uri.query.to_s)['idTypeJustificatif'] == asked }
  end
end

# The sentence stands beside the list, in the group the DSFR puts in its error
# state; its link breaks the rendering over several lines.
Alors('la carte affiche {string}') do |sentence|
  expect(page).to have_css("#{CARD} .fr-select-group--error .fr-error-text", text: sentence, normalize_ws: true)
end

Alors('la liste des pays de la carte affiche {string}') do |country|
  expect(find_field(I18n.t('components.demo_requirement_card.country_label'))).to have_css('option:checked', text: country)
end

Alors('la page des justificatifs a été rechargée') do
  wait_until('La page des justificatifs n\'a pas été rechargée.') { page.evaluate_script('window.pageMark').nil? }
  expect(page).to have_current_path(DOCUMENTS_PAGE)
end

# The region a screen reader hears, which no eye sees: read in the page as the
# assistive technologies read it, hidden or not.
Alors('la carte annonce {string}') do |sentence|
  expect(page).to have_css('[data-demo-card-target="status"]', text: sentence, visible: :all)
end

Alors('le contrat a reçu la demande pour le pays {string}') do |code|
  wait_until("Le contrat n'a reçu aucune demande pour le pays #{code}.") do
    contract_demands.any? { |demand| Rack::Utils.parse_nested_query(demand.uri.query.to_s)['codePays'] == code }
  end
end

# Asked before the held submission is released, which is what it proves: the
# second click does not wait on the first answer.
Alors('le contrat a reçu la demande de la {word} carte') do |rank|
  asked = requirement_uri(REQUIREMENTS.fetch(rank))

  wait_until("Le contrat n'a reçu aucune demande pour la #{rank} exigence.") do
    contract_demands.any? { |demand| Rack::Utils.parse_nested_query(demand.uri.query.to_s)['idExigence'] == asked }
  end
end

# One tick at a time: an absence is waited past rather than waited for, so the
# interval is let by and what went out is counted again.
Alors('aucune autre interrogation ne part') do
  gone = zone_requests.seen.size
  sleep INTERVAL + 1

  expect(zone_requests.seen.size).to eq(gone)
end

# What a lost click is retried as. Chapter 4.4 §4.1 makes a click a new request
# — « a new unique request MUST be issued » — so sending it again would open a
# second exchange while the first is still under way; consulting its address is
# free to be repeated.
Alors('les essais qui suivent la soumission sont des interrogations') do
  wait_until_seen(3)
  attempts = zone_requests.seen.pluck(:method)

  # `uniq` and not the `all` matcher: Capybara's own `all` is in this World and
  # is what the bare name resolves to.
  expect(attempts.first).to eq('POST')
  expect(attempts.drop(1).uniq).to eq(%w[GET])
end

# The whole catalogue of the Evidence Broker, asked with no procedure, beside
# the one requirement the procedure of the journey rests on — which the double
# of the context answers to both questions alike.
Étantdonné("le catalogue de l'Evidence Broker offert sous les cartes de la démarche") do
  stub_directory('eb', 'requirements-by-procedure', 'eb_requirements_catalogue')
  body, headers = common_services_answer('eb_requirements_fr')
  stub_request(:get, "#{DirectoryStubs::ACCEPTANCE}/eb/rest/search")
    .with(query: hash_including('queryId' => a_string_including('requirements-by-procedure'), 'procedure-id' => 'T1'))
    .to_return(body:, headers:)

  visit admin_demo_documents_path(version: 'v2.0', procedure: 'T1')
  mark_the_page
end

# Adding reloads the page, which the steps after it start from.
Quand("l'usager ajoute la carte {string}") do |name|
  select name, from: I18n.t('admin.demo.documents.show.add.label')
  click_button I18n.t('admin.demo.documents.show.add.submit')

  expect(page).to have_css(added_card_selector(name))
  mark_the_page
end

Quand("l'usager choisit {string} dans la liste des pays de la carte {string}") do |country, name|
  label = I18n.t('components.demo_requirement_card.country_label')

  within(added_card_selector(name)) { find_field(label).find('option', text: country).select_option }
end

Quand("l'usager clique sur le bouton de la carte {string}") do |name|
  within(added_card_selector(name)) { click_button press_label }
end

Quand("l'usager retire la carte {string}") do |name|
  within(added_card_selector(name)) { click_button I18n.t('components.demo_requirement_card.remove') }
end

Alors('la carte {string} se tient sous celles de la démarche, avec le bouton {string}') do |name, label|
  cards = all(CARD, minimum: 2)

  expect(cards.last[:id]).to eq("exigence-#{CATALOGUE.fetch(name)}")
  expect(cards.last).to have_button(label)
  expect(cards.first).to have_no_button(label)
end

Alors('la carte {string} nomme le pays {string}') do |name, country|
  expect(find(added_card_selector(name))).to have_css(NAMED_COUNTRY, text: country)
end

Alors("la page n'affiche pas la carte {string}") do |name|
  expect(page).to have_no_css(added_card_selector(name))
end

def added_card_selector(name) = "#exigence-#{CATALOGUE.fetch(name)}"

def zone_requests = intercepted_requests(pattern: ZONE_ADDRESS)

def country_requests = intercepted_requests(pattern: COUNTRY_ADDRESS)

def identify_in_line_1_2
  visit admin_demo_root_path
  click_link 'OOTS 1.2'
  find("a[href='#{admin_demo_home_path(version: 'v1.2', procedure: 'T1')}']").click
  sign_in_with('fake')

  expect(page).to have_current_path(admin_demo_documents_path(version: 'v1.2', procedure: 'T1'))
  mark_the_page
end

def evidence_type_requests = intercepted_requests(pattern: EVIDENCE_TYPE_ADDRESS)

def evidence_type_label = I18n.t('components.demo_requirement_card.evidence_type_label')

def evidence_type_prompt = I18n.t('components.demo_requirement_card.evidence_type_prompt')

def austrian_type_id(uuid) = "https://sr.acc.oots.tech.ec.europa.eu/evidencetypeclassifications/AT/#{uuid}"

# The card a step names, by its rank among those the page renders.
def card(rank) = all(CARD, count: REQUIREMENTS.size)[REQUIREMENTS.keys.index(rank)]

# The card a step names, by its rank among those the page offers a button on.
def card_zone(rank) = all(ZONE, count: REQUIREMENTS.size)[REQUIREMENTS.keys.index(rank)]

def press_label = I18n.t('components.demo_request_zone.submit')

# The sentence alone, the wording carrying a link the translation places.
def disconnected_sentence
  ActionController::Base.helpers.strip_tags(
    I18n.t('components.demo_request_zone.disconnected_html', reload: I18n.t('components.demo_request_zone.reload')),
  )
end

def mark_the_waiting
  page.execute_script("document.querySelector('#{BODY}').dataset.scenarioMark = '#{MARK}'")
end

# Both marks are posed together, the page and the element the answers splice
# into: a reload loses the first, and a replacement of the element the second.
def mark_the_page
  page.execute_script("window.pageMark = '#{PAGE_MARK}'")
  page.execute_script("const zone = document.querySelector('#{ZONE}'); if (zone) zone.dataset.scenarioZone = '#{ZONE_MARK}'")
end

# The click is answered once the register carries the request: from then on,
# what the zone asks for is its state. Counted, because a scenario clicking two
# cards has to know both submissions arrived and not just the first.
def wait_until_registered(count = 1)
  wait_until(-> { "#{Demo::Request.count} demande(s) enregistrée(s) sur #{count} : une soumission n'a pas abouti." }) do
    Demo::Request.count >= count
  end
end

# The requests the double has treated, waited for by count: each is an interval
# after the one before, and Capybara's own waiting governs elements only.
def wait_until_seen(count)
  wait_until(-> { "La zone n'a fait que #{zone_requests.seen.size} requête(s) sur #{count} attendue(s)." },
    seconds: INTERVAL * (count + 2)) { zone_requests.seen.size >= count }
end

# What Capybara does for an element, for everything else this suite waits on: a
# browser and a server work in their own threads, and what they have done is
# true a moment after the step that caused it.
def wait_until(complaint, seconds: Capybara.default_max_wait_time)
  limit = Process.clock_gettime(Process::CLOCK_MONOTONIC) + seconds

  until yield
    raise(complaint.respond_to?(:call) ? complaint.call : complaint) if
      Process.clock_gettime(Process::CLOCK_MONOTONIC) > limit

    sleep 0.05
  end
end

# The address a card posts the answers to the questions of the Data Service
# Directory to, in either line.
ANSWER_ADDRESS = '*/T1/classification_fournisseur*'.freeze

# The Greek evidence type the Data Service Directory asks a question about on
# the acceptance environment, the question it asks, and the list its
# `sdg:ValueExpression` addresses — `dsd_classification_requise_el_8b3b6a31`.
GREEK_TYPE = 'https://sr.acc.oots.tech.ec.europa.eu/evidencetypeclassifications/EL/8b3b6a31-9b62-48d7-8926-997df4f91bb5'.freeze
GREEK_CODE_LIST =
  'https://query.cs.acc.oots.tech.ec.europa.eu/codelists/EL/ProjectathonTestCases/8b3b6a31-9b62-48d7-8926-997df4f91bb5'.freeze

# Each question by the words the card asks it in: the first is the one the
# capture carries, the two others are written beside it to make the three types
# chapter 3.1.4 §4.4.3.3 has a requester support.
QUESTIONS = {
  'Projectathon test case' => '1254f10f-406e-4f28-b1ba-d107b93fa264',
  'Were you born abroad?' => '6e0c0b8a-8c1c-4a8f-9b0e-2f1f6d0f1a01',
  'Your passport number' => '6e0c0b8a-8c1c-4a8f-9b0e-2f1f6d0f1a02',
}.freeze

# The control each form of question is asked in, as the scenario names it.
QUESTION_FORMS = { 'liste' => 'select', '"Yes" ou "No"' => 'radio', 'champ texte' => 'text' }.freeze

# The slot that carries the questions of the capture, and the one element it
# holds.
REQUESTED_CONCEPTS = %r{<rim:Slot name="UserRequestedClassificationConcepts">.*?</rim:Slot>}m
QUESTION_ELEMENT = %r{<rim:Element xsi:type="rim:AnyValueType">.*?</rim:Element>}m

# Greece named in the code list as the scenarios name it, its two evidence types
# published for the requirement of the card, the question of its Data Service
# Directory on the first, the list of values the question addresses, and the
# answer to `TC03` naming `AP_EL_02`. Doubled after the `Contexte`, so that
# WebMock prefers these, and the page asked for again so that its list of
# countries carries the name.
Étantdonné('la Grèce posant une question sur le fournisseur de {string}') do |_title|
  stub_greece
  stub_dsd_for_greece(common_services_answer('dsd_classification_requise_el_8b3b6a31'))
  stub_greek_answer({ QUESTIONS.fetch('Projectathon test case') => 'TC03' }, 'dsd_data_services_el_8b3b6a31_tc03')
  visit current_path
  mark_the_page
end

# The capture's question, then a `boolean` and a `string` written after it in
# the same slot: the acceptance environment asks no such thing, so the answer is
# fabricated beside the capture and its signature doubled.
Étantdonné('la Grèce posant une question de chaque type sur le fournisseur de {string}') do |_title|
  stub_directory_signature
  stub_greece
  body = common_services_answer('dsd_classification_requise_el_8b3b6a31').first.sub(QUESTION_ELEMENT) do |codelist|
    codelist + fabricated_question('boolean', 'Were you born abroad?') + fabricated_question('string', 'Your passport number')
  end
  stub_dsd_for_greece([body, { 'content-type' => 'application/x-ebrs+xml' }])
  stub_greek_answer(
    { QUESTIONS.fetch('Projectathon test case') => 'TC03', QUESTIONS.fetch('Were you born abroad?') => 'true',
      QUESTIONS.fetch('Your passport number') => 'AB123456' }, 'dsd_data_services_el_8b3b6a31_tc03'
  )
  visit current_path
  mark_the_page
end

# `R-DSD-ERR-S022` makes the slot mandatory in a `DSD:ERR:0005`; a directory
# leaving it out asks nothing anybody could answer.
Quand('la Grèce ne pose plus que sa question sans classification') do
  stub_directory_signature
  body = common_services_answer('dsd_classification_requise_el_8b3b6a31').first.sub(REQUESTED_CONCEPTS, '')
  stub_dsd_for_greece([body, { 'content-type' => 'application/x-ebrs+xml' }])
end

Étantdonné('la liste des valeurs de la question injoignable') do
  stub_request(:get, GREEK_CODE_LIST).to_return(status: 503)
end

# `DSD:ERR:0001` is the refusal captured for France, whose signature covers the
# body alone; `DSD:ERR:0006`, which the acceptance environment does not produce,
# is that same capture under the code the table of chapter 3.1.4 §4.4.2 gives
# it, its signature doubled.
Étantdonné('le Data Service Directory refusant la réponse {string} en {string}') do |value, code|
  body, headers = common_services_answer('dsd_aucun_service_fr')
  unless code == 'DSD:ERR:0001'
    stub_directory_signature
    body = body.sub('DSD:ERR:0001', code)
  end

  stub_greek_answer({ QUESTIONS.fetch('Projectathon test case') => value }, [body, headers])
end

Étantdonné('la réponse aux questions répondue en {string} sans l\'en-tête "Deferred-Fragment", puis coupée, devant le navigateur') do |status|
  answer_requests.answer(status: status.to_i, body: BAD_GATEWAY_PAGE).cut
end

# Whatever the control: the value a list offers, the label of a radio button,
# the words typed in a field.
Quand("l'usager répond {string} à la question {string}") do |value, question|
  group = question_group(question)

  case question_control(group)
  when 'select' then group.find('select').find('option', exact_text: value).select_option
  when 'radio' then group.find('label', exact_text: value).click
  else group.find('input').tap { |field| field.set(value) }.send_keys(:enter)
  end
end

Alors('la carte pose la question {string} dans une liste ouverte sur {string}') do |question, prompt|
  expect(question_control(question_group(question))).to eq('select')
  expect(question_group(question).find('select')).to have_css('option:checked', exact_text: prompt)
end

Alors('la carte pose la question {string} dans un champ texte') do |question|
  expect(question_control(question_group(question))).to eq('text')
end

Alors("la carte pose, dans l'ordre, les questions :") do |table|
  asked = all("#{CARD} [data-demo-card-question]").map do |group|
    [group.first('label, legend').text.sub(directory_value_meaning, '').squish, question_control(group)]
  end

  expect(asked).to eq(table.hashes.map { |row| [row['question'], QUESTION_FORMS.fetch(row['forme'])] })
end

Alors('la question {string} offre {string}') do |question, value|
  expect(question_group(question).find('select')).to have_css('option', exact_text: value)
end

Alors("la question {string} n'offre plus {string}") do |question, value|
  expect(question_group(question).find('select')).to have_no_css('option', exact_text: value)
end

Alors('la question {string} affiche {string}') do |question, value|
  group = question_group(question)

  if question_control(group) == 'select'
    expect(group.find('select')).to have_css('option:checked', exact_text: value)
  else
    expect(group.find('input').value).to eq(value)
  end
end

# Each answer leaves as it is given, as a country or a type chosen does.
Alors("la carte n'offre pas de bouton pour répondre") do
  expect(find(CARD)).to have_no_css('form.requirement-card__questions button')
end

Alors("la carte n'offre aucune question") do
  expect(find(CARD)).to have_no_css('[data-demo-card-question]')
end

Alors('la carte affiche sous ses questions {string}') do |sentence|
  expect(page).to have_css("#{CARD} [data-demo-card-target='answerFailure']", text: sentence, normalize_ws: true)
end

Alors("le Data Service Directory n'a reçu aucune réponse") do
  expect(directory_queries.select { |query| QUESTIONS.values.any? { |id| query.key?(id) } }).to be_empty
end

# Chapter 3.1.4 §4.4.3.3: the same query, a parameter per question named by
# its identifier.
Alors('le Data Service Directory a reçu la réponse {string} à la question {string}') do |value, question|
  expect(answered_query(QUESTIONS.fetch(question) => value)).to have_been_made.at_least_once
end

# The rendering of a card that has its answer replays both: the exception of
# the first is the only source of the questions.
Alors('le Data Service Directory a reçu sa requête sans la réponse, puis avec elle') do
  question = QUESTIONS.fetch('Projectathon test case')

  expect(answered_query(question => 'TC03')).to have_been_made.at_least_twice
  asked = directory_queries.select { |query| query['evidence-type-classification'] == GREEK_TYPE && !query.key?(question) }

  expect(asked.size).to be >= 2
end

Alors('le contrat a reçu la demande avec la réponse {string} à la question {string}') do |value, question|
  wait_until("Le contrat n'a reçu aucune demande portant la réponse #{value}.") do
    contract_demands.any? do |demand|
      Rack::Utils.parse_nested_query(demand.uri.query.to_s).dig('classificationFournisseur', QUESTIONS.fetch(question)) == value
    end
  end
end

def answer_requests = intercepted_requests(pattern: ANSWER_ADDRESS)

# The queries the Data Service Directory received, each read as the route reads
# it, counted the way `contract_demands` counts the demands of the contract.
def directory_queries
  WebMock::RequestRegistry.instance.requested_signatures.hash.flat_map do |signature, times|
    next [] unless signature.uri.path == '/dsd/rest/search'

    [Rack::Utils.parse_query(signature.uri.query.to_s)] * times
  end
end

def stub_greece
  stub_code_list(country_names: CodeListStubs::DEFAULT_COUNTRY_NAMES.merge('EL' => 'Greece'))
  stub_directory('eb', 'evidence-types-by-requirement', 'eb_evidence_types_el', country: 'EL')
  stub_request(:get, GREEK_CODE_LIST)
    .to_return(body: Rails.root.join('spec/fixtures/common_services/liste_classification_el_projectathon.gc').read,
      headers: { 'Content-Type' => 'text/plain;charset=UTF-8' })
end

def stub_dsd_for_greece((body, headers))
  stub_directory_body('dsd', 'dataservices-by-evidencetype', body, headers, evidence_type: GREEK_TYPE)
end

# Declared after the question, so that WebMock, which takes the last stub
# matching, serves it to the query carrying these answers alone.
def stub_greek_answer(answers, answer)
  body, headers = answer.is_a?(String) ? common_services_answer(answer) : answer

  stub_request(:get, "#{DirectoryStubs::ACCEPTANCE}/dsd/rest/search")
    .with(query: hash_including('evidence-type-classification' => GREEK_TYPE, **answers))
    .to_return(body:, headers:)
end

def answered_query(answers)
  a_request(:get, "#{DirectoryStubs::ACCEPTANCE}/dsd/rest/search")
    .with(query: hash_including('evidence-type-classification' => GREEK_TYPE, 'country-code' => 'EL', **answers))
end

def fabricated_question(type, question)
  <<~XML
    <rim:Element xsi:type="rim:AnyValueType">
        <sdg:EvidenceProviderClassification>
            <sdg:Identifier>#{QUESTIONS.fetch(question)}</sdg:Identifier>
            <sdg:Type>#{type}</sdg:Type>
            <sdg:Description lang="EN">#{question}</sdg:Description>
        </sdg:EvidenceProviderClassification>
    </rim:Element>
  XML
end

# The group of one question, found by the words it is asked in.
def question_group(question)
  find("#{CARD} [data-demo-card-question]", text: question)
end

def question_control(group)
  return 'select' if group.has_css?('select', wait: false)
  return 'radio' if group.has_css?('input[type=radio]', visible: :all, wait: false)

  'text'
end

def directory_value_meaning = I18n.t('components.directory_value.meaning')
