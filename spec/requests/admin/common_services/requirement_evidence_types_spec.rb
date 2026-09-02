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

  # Two alternatives calling on the same evidence type — the `OR` of chapter
  # 3.2.4, whose consequence for counting `EvidenceTypeList` documents. Counting
  # memberships would announce two where the country publishes one, on a page
  # whose whole job is to say what a jurisdiction holds.
  it 'counts an evidence type once where two combinations publish it' do
    stub_directory_signature
    stub_directory_body('eb', 'evidence-types-by-requirement', same_type_twice)

    get admin_common_services_requirement_path(test_requirement)
    weights = response.parsed_body.css('#par-pays-fournisseur > *').map { |one| one['data-tally-weight'].to_i }

    expect(response.parsed_body.css('#decompte-types').text).to include('Un résultat')
    expect(weights).to eq([1])
  end

  # Only the tally changes: which combinations a country publishes is what this
  # page exists to show, and the `OR` between them is visible nowhere else.
  it 'keeps both combinations, and the type each of them calls on' do
    stub_directory_signature
    stub_directory_body('eb', 'evidence-types-by-requirement', same_type_twice)

    get admin_common_services_requirement_path(test_requirement)

    expect(response.body.scan('Combinaison').size).to eq(2)
    expect(response.parsed_body.css('.entry .entry__name').map(&:text)).to eq(['FR - Test Evidence Type'] * 2)
  end

  # What the page counts is (country, type) pairs, so a type two jurisdictions
  # publish weighs one on each of their cards. Chapter 3.2.4 says nothing of
  # that case either way — it is silent, not permissive — which is precisely why
  # the page must not be built on its not happening: `filter.js` sums the weights
  # on load, so the reader sees the weights whenever heading and cards disagree.
  it 'counts a type published by two countries once per country, as its cards do' do
    stub_directory_signature
    stub_directory_body('eb', 'evidence-types-by-requirement', same_type_in_two_countries)

    get admin_common_services_requirement_path(test_requirement)
    weights = response.parsed_body.css('#par-pays-fournisseur > *').map { |one| one['data-tally-weight'].to_i }

    expect(weights).to eq([1, 1])
    expect(response.parsed_body.css('#decompte-types').text).to include('2 résultats')
  end

  # A second combination, for the same country, built from the captured
  # response: the fixture carries only one.
  def two_combinations
    common_services_answer('eb_evidence_types_fr').first.sub(
      %r{(<sdg:EvidenceTypeList>.*?</sdg:EvidenceTypeList>)}m,
    ) { "#{Regexp.last_match(1)}#{Regexp.last_match(1).sub('869a6748', 'ffffffff')}" }
  end

  # The same, this time leaving the evidence type classification alone: two
  # combinations of one country calling on the very same type, which is what
  # the Evidence Broker publishes when its alternatives overlap. Only the list
  # identifier differs, since it is what tells two combinations apart.
  def same_type_twice
    common_services_answer('eb_evidence_types_fr').first.sub(
      %r{(<sdg:EvidenceTypeList>.*?</sdg:EvidenceTypeList>)}m,
    ) { "#{Regexp.last_match(1)}#{Regexp.last_match(1).sub('91ecb80f', 'ffffffff')}" }
  end

  # The same evidence type published by two jurisdictions: the copy keeps the
  # classification and changes the country it is filed under, so the page draws
  # two cards weighing one each.
  def same_type_in_two_countries
    common_services_answer('eb_evidence_types_fr').first.sub(
      %r{(<sdg:EvidenceTypeList>.*?</sdg:EvidenceTypeList>)}m,
    ) do
      published = Regexp.last_match(1)

      published + published.sub('91ecb80f', 'ffffffff')
        .sub('<sdg:AdminUnitLevel1>FR</sdg:AdminUnitLevel1>',
          '<sdg:AdminUnitLevel1>DE</sdg:AdminUnitLevel1>')
    end
  end

  # A list the directory publishes empty on purpose (chapter 3.2.4) would show
  # as a card with nothing in it, which reads as a page that failed rather than
  # as the declaration it is.
  describe 'une déclaration explicite de non-délivrance' do
    before do
      stub_directory_signature
      stub_directory_body('eb', 'evidence-types-by-requirement', evidence_types_declaring_no_match(reason:))
    end

    let(:reason) { 'No MS-issued evidence available for SMEs in Dutch Speaking Community' }

    it 'says the country declares it issues nothing, and why' do
      get admin_common_services_requirement_path(test_requirement)

      expect(response.body).to include('Ce pays déclare ne délivrer aucun justificatif', reason)
    end

    # `sdg:MatchDescription` is optional, and the declaration stands without it.
    it 'says it even where the directory published no reason' do
      stub_directory_body('eb', 'evidence-types-by-requirement', evidence_types_declaring_no_match)

      get admin_common_services_requirement_path(test_requirement)

      expect(response.body).to include('Ce pays déclare ne délivrer aucun justificatif')
    end

    # The reason is published in the member state's own language, and the page
    # is French: unmarked, a screen reader reads the English aloud in French
    # (RGAA 8.7).
    it 'declares the language the reason is written in' do
      get admin_common_services_requirement_path(test_requirement)

      expect(response.parsed_body.css('.fr-hint-text[lang=en]').text).to include(reason)
    end

    # `R-EB-EVI-C045` makes `lang` mandatory and names `EN` as its default, and
    # nothing enforces either on the wire. The default is the publisher's to
    # apply: guessing it here would declare a language we do not know.
    it 'leaves the attribute out where the directory declared no language' do
      stub_directory_body('eb', 'evidence-types-by-requirement',
        evidence_types_declaring_no_match(reason:).sub(' lang="EN">No MS-issued', '>No MS-issued'))

      get admin_common_services_requirement_path(test_requirement)

      expect(response.body).to include(reason)
      expect(response.parsed_body.css('.fr-hint-text[lang]')).to be_empty
    end

    # The precondition of the empty state below, and the whole reason `filter.js`
    # counts entries apart from the tally: this card is on screen and weighs
    # nothing, the tally weighing evidence types. Keyed on that weight, the page
    # announced that nothing matched under a card the reader had before them.
    it 'shows a card that weighs nothing, the country publishing no type' do
      get admin_common_services_requirement_path(test_requirement)

      entries = response.parsed_body.css('#par-pays-fournisseur > *')

      expect(entries.size).to eq(1)
      expect(entries.first['data-tally-weight']).to eq('0')
    end

    # Only what the server renders. What decides the empty state once the page
    # is live is `filter.js`, which no suite of this repository can exercise —
    # that half is verified in a browser, and this pins the other.
    it 'renders its empty state hidden, the declaration being a card of its own' do
      get admin_common_services_requirement_path(test_requirement)

      expect(response.parsed_body.css('#aucun-type').attr('hidden')).to be_present
    end
  end

  # A country may publish one combination and declare it issues nothing under
  # another, the jurisdictions differing. The page shows both, each named.
  it 'renders a declaration beside a combination that carries types' do
    stub_directory_signature
    stub_directory_body('eb', 'evidence-types-by-requirement', evidence_types_declaring_no_match_beside_types)

    get admin_common_services_requirement_path(test_requirement)

    expect(response.body).to include('FR - Test Evidence Type', 'Ce pays déclare ne délivrer aucun justificatif')
    expect(response.body).to include('Combinaison')
  end

  # The other side of that condition: a search that really turns up nothing
  # still says so.
  it 'keeps its empty state for a requirement no country satisfies' do
    stub_directory('eb', 'evidence-types-by-requirement', 'eb_requirements_vides')

    get admin_common_services_requirement_path(test_requirement)

    expect(response.body).to include('EB:ERR:0001')
  end

  it 'answers 404 for a requirement the directory does not publish' do
    get admin_common_services_requirement_path('00000000-0000-0000-0000-999999999999')

    expect(response).to have_http_status(:not_found)
  end
end
