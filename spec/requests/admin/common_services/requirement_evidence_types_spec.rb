require 'rails_helper'

RSpec.describe 'Admin::CommonServices::Requirements, les types de justificatif' do
  let(:test_requirement) { '00000000-0000-0000-0000-000000000000' }

  before do
    sign_in
    stub_code_list
    stub_directory_resolution
    stub_directory('eb', 'requirements-by-procedure', 'eb_requirements_catalogue')
    stub_directory('eb', 'evidence-types-by-requirement', 'eb_evidence_types_fr')
  end

  it 'lists what satisfies the requirement, and says which requirement' do
    get admin_common_services_requirement_path(test_requirement)

    expect(response.body).to include('(TEST) Test Requirement', 'FR - Test Evidence Type')
    expect(response.body).to include('Un résultat')
  end

  # Twenty-four cards down, the page title is off screen: the preposition
  # follows the article from the code list, failing which the sentence would
  # read « en Pays-Bas ».
  it 'says on each card which requirement, and situates the jurisdiction' do
    stub_code_list(countries: { 'FR' => 'France (la)' })

    get admin_common_services_requirement_path(test_requirement)

    expect(response.parsed_body.css('.fr-card__desc').text)
      .to include("Ce qui satisfait l'exigence", '(TEST) Test Requirement', 'en France')
  end

  # `country-code` is optional on this query, so the answer carries every
  # country at once and the page names none.
  it 'asks the directory without naming a country' do
    get admin_common_services_requirement_path(test_requirement)

    expect(a_request(:get, "#{DirectoryStubs::ACCEPTANCE}/eb/rest/search")
      .with(query: hash_including('requirement-id' => a_string_including(test_requirement)))).to have_been_made
    expect(a_request(:get, "#{DirectoryStubs::ACCEPTANCE}/eb/rest/search")
      .with(query: hash_including('country-code' => 'FR', 'requirement-id' => a_string_including('requirements'))))
      .not_to have_been_made
  end

  # Twenty-seven jurisdictions at most, so the narrowing happens in the browser
  # rather than by a round trip per keystroke.
  it 'hands every jurisdiction to a search box rather than filtering server-side' do
    get admin_common_services_requirement_path(test_requirement)

    expect(response.parsed_body.css('input[data-filter]').first['data-filter'])
      .to eq('#par-pays-fournisseur > *')
    expect(response.parsed_body.css('#par-pays-fournisseur > *')).not_to be_empty
  end

  # A jurisdiction weighs what it publishes: the tally counts evidence types,
  # and hiding a country has to take its own away.
  it 'weighs each jurisdiction with the types it publishes' do
    get admin_common_services_requirement_path(test_requirement)

    weights = response.parsed_body.css('#par-pays-fournisseur > *').map { |one| one['data-tally-weight'].to_i }

    expect(weights).to all(be_positive)
    expect(weights.sum).to eq(1)
  end

  # The evidence type carries its own jurisdiction: the address need not repeat
  # it, and repeating it would allow the two to contradict each other.
  it 'leads to the providers of a type without naming a country in the address' do
    get admin_common_services_requirement_path(test_requirement)

    expect(response.parsed_body.css("a[href$='/providers']")).to be_present
    expect(response.parsed_body.css("a[href*='country_code']")).to be_empty
  end

  # Two combinations are alternatives, and the evidence types within one are
  # required together: the word is said only where it settles something.
  it 'names the combination only where a country publishes more than one' do
    stub_directory('eb', 'evidence-types-by-requirement', 'eb_evidence_types_fi')

    get admin_common_services_requirement_path(test_requirement)

    expect(response.body).not_to include('Combinaison')
  end

  it 'names each combination when a country publishes several' do
    stub_directory_signature
    stub_directory_body('eb', 'evidence-types-by-requirement', two_combinations)

    get admin_common_services_requirement_path(test_requirement)

    expect(response.body).to include('Combinaison', "exigée d'un bloc")
  end

  # A second combination, for the same country, built from the captured
  # response: the fixture carries only one.
  def two_combinations
    common_services_answer('eb_evidence_types_fr').first.sub(
      %r{(<sdg:EvidenceTypeList>.*?</sdg:EvidenceTypeList>)}m,
    ) { "#{Regexp.last_match(1)}#{Regexp.last_match(1).sub('869a6748', 'ffffffff')}" }
  end

  it 'answers 404 for a requirement the directory does not publish' do
    get admin_common_services_requirement_path('00000000-0000-0000-0000-999999999999')

    expect(response).to have_http_status(:not_found)
  end
end
