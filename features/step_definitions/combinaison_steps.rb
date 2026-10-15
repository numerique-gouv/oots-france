# The two evidence types of « Compound test evidence », the combination Greece
# publishes for « (TEST) Test Requirement » in `eb_evidence_types_el`, by the
# title the card shows: what the contract receives in `idTypeJustificatif`, and
# the exchange the double opens for each.
GREEK_COMBINED_TYPES = {
  'Projectathon test evidence' => '8b3b6a31-9b62-48d7-8926-997df4f91bb5',
  'Simple test evidence' => '8b0aeabd-a0fd-4c62-bb15-71282fbf5992',
}.freeze
GREEK_EXCHANGES = {
  'Projectathon test evidence' => 'aaaaaaaa-0000-4000-8000-0000000000b1',
  'Simple test evidence' => 'aaaaaaaa-0000-4000-8000-0000000000c1',
}.freeze

# The three lists of the capture, by the words a scenario names them with.
GREEK_LISTS = {
  'Simple test evidence' => '41486aa9-ecc4-48ea-b097-4f7329e21218',
  'Projectathon test evidence' => 'f9e8ba9d-b82b-4ced-b697-ebd153262a6d',
  'Compound test evidence' => 'e9bb55fc-e744-493d-ab9d-055f9c7e1d28',
}.freeze

EVIDENCE_TYPE_LIST = %r{<sdg:EvidenceTypeList>.*?</sdg:EvidenceTypeList>}m

# Greece as the capture has it — each type on its own list, then the two on
# « Compound test evidence » —, the question on « Projectathon test evidence »,
# answered `TC03`, and « Simple test evidence » named without one. Each type
# opens its own exchange at the contract.
Étantdonné("la Grèce publiant {string} pour l'exigence de la carte") do |combination|
  GREEK_LISTS.fetch(combination)
  stub_greek_combination
  visit current_path
  mark_the_page
end

# The capture rebuilt from its own lists, each row one of them: as published,
# without its `sdg:Name`, under another jurisdiction, or a `NoMatch` in place.
# Its signature doubled: a capture is signed over its bytes.
Étantdonné("la Grèce publiant pour l'exigence de la carte les listes :") do |table|
  stub_greek_combination
  stub_directory_signature
  body = common_services_answer('eb_evidence_types_el').first
  lists = table.hashes.map { |row| greek_list(body, row.fetch('liste')) }
  first = body.index(EVIDENCE_TYPE_LIST)
  last_start = body.rindex(EVIDENCE_TYPE_LIST)
  last = last_start + body[last_start..][EVIDENCE_TYPE_LIST].size

  stub_directory_body('eb', 'evidence-types-by-requirement', body[...first] + lists.join + body[last..], country: 'EL')
  visit current_path
  mark_the_page
end

# The acceptance environment asks a question on « Projectathon test evidence »;
# its answer to `TC03` is served here to the query that asks nothing, so that
# the provider is named without one.
Étantdonné('la Grèce désignant sans question le fournisseur de {string}') do |_title|
  stub_dsd_for_greece(common_services_answer('dsd_data_services_el_8b3b6a31_tc03'))
end

Étantdonné('aucun fournisseur publié en Grèce pour {string}') do |title|
  stub_directory('dsd', 'dataservices-by-evidencetype', 'dsd_aucun_service_fr', evidence_type: greek_type_id(title))
end

Étantdonné('le contrat refusant la demande de {string}') do |title|
  stub_evidence_request_for_type(greek_type_id(title), nil, status: 422, error: 'EB:ERR:0001')
end

Quand("l'usager clique sur {string} dans le bloc de {string}") do |label, title|
  within(zone_block(title)) { click_button label, exact: true }
end

# The zone re-asks its own address while a block waits, and each time the
# contract is asked the state of that block's exchange: two more such readings
# are two polls the zone has answered.
Quand('la zone a interrogé deux fois de plus son adresse') do
  readings = -> { state_readings(GREEK_EXCHANGES.fetch('Projectathon test evidence')) }
  seen = readings.call

  wait_until('La zone ne réinterroge pas son adresse.', seconds: INTERVAL * 4) { readings.call >= seen + 2 }
end

Quand('chaque demande de la combinaison est refusée') do
  GREEK_EXCHANGES.each_value { |exchange| stub_exchange_state(exchange, statut: 'failed', codeErreur: 'EDM:ERR:0003') }
end

Alors("la liste des combinaisons de la carte offre, dans l'ordre :") do |table|
  offered = find_field(combination_label).all('option').map(&:text).reject { |text| text == combination_prompt }

  expect(offered).to eq(table.hashes.pluck('combinaison'))
end

# The two names requirement 27 of chapter 1 §2 has shown before any request,
# for each type of the combination.
Alors('la carte nomme, ligne par ligne :') do |table|
  expected = table.hashes.map { |row| "#{row.fetch('type')} from #{row.fetch('fournisseur')}" }

  expect(page).to have_css(CARD_LINE, count: expected.size)
  wait_until(-> { "La carte nomme #{all(CARD_LINE).map { |line| said_by(line) }}." }) do
    all(CARD_LINE).map { |line| said_by(line) } == expected
  end
end

Alors('la ligne de {string} pose la question {string}') do |title, question|
  expect(card_line(title)).to have_css('[data-demo-card-question]', text: question)
end

Alors('la ligne de {string} affiche {string}') do |title, sentence|
  resolution = -> { said_by(card_line(title).find('[data-demo-card-target~="resolution"]')) }

  wait_until(-> { "La ligne de #{title} affiche « #{resolution.call} »." }) { resolution.call.include?(sentence) }
end

# Chapter 4.4 §4.3.2: the `ConversationId` « SHOULD be reused for combined
# flows ».
Alors("le contrat a reçu, dans l'ordre et sous la même conversation, les demandes :") do |table|
  expected = table.hashes.map { |row| greek_type_id(row.fetch('type')) }

  wait_until("Le contrat n'a pas reçu les #{expected.size} demandes attendues.") { every_demand.size >= expected.size }
  expect(every_demand.map { |demand| demand_query(demand)['idTypeJustificatif'] }).to eq(expected)
  expect(conversations_asked.uniq.size).to eq(1)
end

Alors("le contrat n'a reçu de demande que pour {string}") do |title|
  expect(every_demand.map { |demand| demand_query(demand)['idTypeJustificatif'] }).to eq([greek_type_id(title)])
end

Alors("la zone affiche un bloc par type, dans l'ordre :") do |table|
  expect(page).to have_css(ZONE_BLOCK_TYPE, count: table.hashes.size)
  expect(all(ZONE_BLOCK_TYPE).map { |name| said_by(name) }).to eq(table.hashes.pluck('type'))
end

Alors('le bloc de {string} affiche {string}') do |title, sentence|
  expect(zone_block(title)).to have_text(sentence)
end

Alors("le bloc de {string} n'affiche pas {string}") do |title, sentence|
  expect(zone_block(title)).to have_no_text(sentence)
end

CARD_LINE = '[data-demo-card-line]'.freeze
ZONE_BLOCK_TYPE = '[data-demo-request-block] .demo-request__type'.freeze

def stub_greek_combination
  stub_greece
  stub_dsd_for_greece(common_services_answer('dsd_classification_requise_el_8b3b6a31'))
  stub_greek_answer({ QUESTIONS.fetch('Projectathon test case') => 'TC03' }, 'dsd_data_services_el_8b3b6a31_tc03')
  stub_directory('dsd', 'dataservices-by-evidencetype', 'dsd_data_services_el_8b0aeabd',
    evidence_type: greek_type_id('Simple test evidence'))
  GREEK_EXCHANGES.each do |title, exchange|
    stub_evidence_request_for_type(greek_type_id(title), exchange)
    stub_exchange_state(exchange, statut: 'pending')
  end
end

def greek_type_id(title)
  "https://sr.acc.oots.tech.ec.europa.eu/evidencetypeclassifications/EL/#{GREEK_COMBINED_TYPES.fetch(title)}"
end

# One list of the capture, as a row of the scenario names it.
def greek_list(body, row)
  return "<sdg:EvidenceTypeList><sdg:Identifier>rien</sdg:Identifier>#{no_match_declaration}</sdg:EvidenceTypeList>" if
    row.include?('NoMatch')

  title, variant = row.split(', ', 2)
  list = body.scan(EVIDENCE_TYPE_LIST).find { |found| found.include?(GREEK_LISTS.fetch(title)) }

  case variant
  when 'sans nom' then list.gsub(%r{<sdg:Name lang="EN">[^<]*</sdg:Name>}, '')
  when 'sous une autre juridiction'
    list.sub(GREEK_LISTS.fetch(title), 'ailleurs').sub('<sdg:AdminUnitLevel1>EL</sdg:AdminUnitLevel1>',
      '<sdg:AdminUnitLevel1>EL</sdg:AdminUnitLevel1><sdg:AdminUnitLevel2>EL3</sdg:AdminUnitLevel2>')
  else list
  end
end

def card_line(title) = find("#{CARD_LINE}[data-demo-card-line='#{GREEK_COMBINED_TYPES.fetch(title)}']")

def zone_block(title) = find('[data-demo-request-block]', text: title)

def state_readings(exchange)
  # A copy taken in one call: the server thread adds to the registry while it is
  # read, and a hash grown during iteration raises there.
  WebMock::RequestRegistry.instance.requested_signatures.hash.to_a
    .sum { |signature, times| signature.uri.path == "/requete/#{exchange}" ? times : 0 }
end

# Each demand as many times as it was made: `contract_demands` counts two
# identical demands once, and a type asked twice is exactly what these steps
# must see.
def every_demand
  WebMock::RequestRegistry.instance.requested_signatures.hash.to_a
    .flat_map { |signature, times| signature.uri.path == DemoContractStubs::PATH ? [signature] * times : [] }
end

def demand_query(demand) = Rack::Utils.parse_nested_query(demand.uri.query.to_s)

# What an element says, less what `DirectoryValueComponent` adds for a screen
# reader after each value the directories publish.
def said_by(element) = element.text.gsub(directory_value_meaning, '').squish
