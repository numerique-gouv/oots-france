# The requirement the acceptance catalogue publishes as a test entry, and the
# one page built around a single requirement addresses by its identifier.
TEST_REQUIREMENT = '00000000-0000-0000-0000-000000000000'.freeze

# Why a member state says it issues nothing, as chapter 3.2.4 lets it attach to
# a `NoMatch`.
NO_MATCH_REASON = 'No MS-issued evidence available for SMEs in Dutch Speaking Community'.freeze

# What nginx answers out of its own pocket when nothing runs behind it, which is
# the document `Deferred-Fragment` exists to keep out of the console. Its title
# is what a scenario looks for: were it spliced in, it would be on screen.
BAD_GATEWAY_PAGE = '<html><head><title>502 Bad Gateway</title></head>' \
                   '<body><center><h1>502 Bad Gateway</h1></center></body></html>'.freeze

BAD_GATEWAY_MARKER = '502 Bad Gateway'.freeze

# The address the two pages served in two parts fetch. Narrowed to it on
# purpose: everything else the page loads — its stylesheets, the import map, the
# controllers themselves — must not be paused along with it.
LISTING = '*listing=1*'.freeze

Étantdonné('un Evidence Broker qui publie le catalogue des exigences') do
  stub_code_list
  stub_directory('eb', 'requirements-by-procedure', 'eb_requirements_catalogue')
  stub_directory('eb', 'evidence-types-by-requirement', 'eb_evidence_types_fr')
end

# `query:` and not the bare address: a WebMock stub written without one answers
# only a request that carries no query string, and every directory query carries
# its `queryId`.
Étantdonné('un Evidence Broker qui ne répond pas') do
  stub_request(:get, "#{DirectoryStubs::ACCEPTANCE}/eb/rest/search")
    .with(query: hash_including({})).to_timeout
end

# The captured answers are signed over their bytes, so the one case they do not
# hold has to be fabricated — and the signature doubled with it, or the
# verification would refuse the fabrication before the page ever saw it.
Étantdonné('une exigence dont le seul pays fournisseur déclare ne délivrer aucun justificatif') do
  stub_directory_signature
  stub_directory_body('eb', 'evidence-types-by-requirement',
    evidence_types_declaring_no_match(reason: NO_MATCH_REASON))
end

# What each jurisdiction of the fabricated answer publishes. Unequal on purpose,
# and summing to a number none of them carries: a page reporting the last card's
# weight instead of the sum cannot be told apart where every card weighs alike.
TYPES_BY_COUNTRY = { 'AT' => 3, 'FR' => 2, 'FI' => 4 }.freeze

# Austria beside the countries the other scenarios need — the argument replaces
# the default list rather than adding to it. A card whose country the list does
# not name writes the bare code, without brackets, and there would be nothing
# left to tell apart. Named in both columns, as the published list names it: the
# console reads the French one, the demonstration's own page the English one.
#
# « AT » is the code retained because it begins no word the card carries:
# « Autriche » begins « au », « satisfait » holds « at » without starting on it,
# and the only word of the card starting « at » is the code in brackets. « FR »
# would have discriminated nothing, « France » beginning with it — which is the
# hole this scenario exists to close.
NAMED_COUNTRIES = CodeListStubs::DEFAULT_COUNTRY_NAMES.merge('AT' => 'Austria').freeze
FRENCH_COUNTRIES = CodeListStubs::DEFAULT_COUNTRIES.merge('AT' => 'Autriche (l’)').freeze

Étantdonné('une exigence que plusieurs pays satisfont, chacun avec plusieurs justificatifs') do
  stub_code_list(countries: FRENCH_COUNTRIES, country_names: NAMED_COUNTRIES)
  stub_directory_signature
  stub_directory_body('eb', 'evidence-types-by-requirement', evidence_types_published_by(TYPES_BY_COUNTRY))
end

Étantdonné('le contenu de la page des exigences est retenu') do
  listing_request.hold
end

Étantdonné("une réponse sans l'en-tête \"Deferred-Fragment\" est fabriquée devant le navigateur") do
  listing_request.answer(status: 502, body: BAD_GATEWAY_PAGE)
end

Étantdonné('la connexion est coupée avant que le contenu soit servi') do
  listing_request.cut
end

# The listing on screen, which is where every search starts: the page is opened
# and its content served, both being the subject of their own scenarios above.
Étantdonné('la liste des exigences affichée') do
  visit admin_common_services_requirements_path
  expect(page).to have_css('#liste-exigences > *', minimum: 2)
end

Quand("l'administrateur ouvre la page des exigences") do
  visit admin_common_services_requirements_path
end

Quand("l'administrateur ouvre la page de cette exigence") do
  visit admin_common_services_requirement_path(TEST_REQUIREMENT)
end

Quand('le contenu est servi') do
  listing_request.release
end

Quand('son compte est supprimé') do
  @administrator.destroy!
end

Quand('un autre administrateur se connecte') do
  @administrator = create(:administrator)
  sign_in(@administrator.password)
end

Quand(/^(?:l'administrateur|il) cherche "([^"]*)"$/) do |terms|
  filter_field.set(terms)
end

# Emptied by keystroke, as whoever typed empties it: the field acts on `input`,
# and assigning an empty value fires none.
Quand('il efface sa recherche') do
  filter_field.send_keys([:control, 'a'], :backspace)
end

Alors("la zone d'attente annonce {string}") do |sentence|
  expect(page).to have_css('.deferred-content [role="status"]', text: sentence)
end

Alors('son tourniquet est affiché') do
  expect(page).to have_css('.deferred-content__spinner')
end

Alors("son tourniquet n'est plus affiché") do
  expect(page).to have_no_css('.deferred-content__spinner')
end

Alors('la page affiche la liste des exigences, son décompte et son champ de recherche') do
  expect(page).to have_css('#liste-exigences > *', minimum: 2)
  expect(page).to have_css('[data-tally]')
  expect(page).to have_field(I18n.t('admin.common_services.requirements.index.search'))
end

Alors("la zone d'attente a disparu") do
  expect(page).to have_no_css('.deferred-content')
end

Alors('la page affiche {string}') do |sentence|
  expect(page).to have_text(sentence)
end

Alors("la page n'affiche pas {string}") do |sentence|
  expect(page).to have_no_text(sentence)
end

Alors("la page affiche l'alerte {string}") do |title|
  expect(page).to have_css('.fr-alert', text: title)
end

Alors("la page n'affiche rien de cette réponse") do
  expect(page).to have_no_text(BAD_GATEWAY_MARKER)
end

Alors("seule l'exigence {string} reste affichée") do |name|
  expect(page).to have_css('#liste-exigences > *', count: 1)
  expect(page).to have_css('#liste-exigences > *', text: name)
end

Alors('le décompte dit {string}') do |tally|
  expect(page).to have_css('[data-tally]', text: tally)
end

# The country the requirement's page shows as a provider, written as the page
# writes it: its name, then its code in brackets.
Alors('la carte du pays est affichée') do
  expect(page).to have_css('#par-pays-fournisseur > *', count: 1)
  expect(page).to have_css('#par-pays-fournisseur > *', text: 'France (FR)')
end

Alors('seule la carte du pays {string} reste affichée') do |named|
  expect(page).to have_css('#par-pays-fournisseur > *', count: 1)
  expect(page).to have_css('#par-pays-fournisseur > *', text: named)
end

# What makes the tally above worth reading: the sum of the weights is a number
# no single card carries, so a page announcing one card's weight would say
# something else.
Alors('aucune carte ne pèse ce nombre à elle seule') do
  weights = all('#par-pays-fournisseur > *', visible: :all).map { |card| card['data-tally-weight'].to_i }

  expect(weights).not_to include(weights.sum)
end

Alors("la carte du pays n'est plus affichée") do
  expect(page).to have_no_css('#par-pays-fournisseur > *')
end

# Whole, and not the bare fragment of its content: the guard remembered the
# address of the page it refused, and not the one the browser was fetching.
Alors("la page des exigences s'affiche entière, avec son titre et sa liste") do
  expect(page).to have_current_path(admin_common_services_requirements_path)
  expect(page).to have_css('h1', text: I18n.t('admin.common_services.requirements.index.title'))
  expect(page).to have_css('#liste-exigences > *', minimum: 2)
end

# The only field of these pages, wherever it sits: what it narrows is named by
# the page, and a scenario types into the one the page carries.
def filter_field = find('input[data-controller="filter"]')

# The listing these pages go and fetch, and the one request of theirs any
# scenario here is about.
def listing_request = intercepted_requests(pattern: LISTING)
