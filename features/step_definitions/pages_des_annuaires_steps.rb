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

Étantdonné('le contenu de la page des exigences est retenu') do
  deferred_request.hold
end

Étantdonné("une réponse sans l'en-tête \"Deferred-Fragment\" est fabriquée devant le navigateur") do
  deferred_request.answer(status: 502, body: BAD_GATEWAY_PAGE)
end

Étantdonné('la connexion est coupée avant que le contenu soit servi') do
  deferred_request.cut
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
  deferred_request.release
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
