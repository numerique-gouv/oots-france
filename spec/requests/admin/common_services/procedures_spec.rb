require 'rails_helper'

# Read against the whole catalogue the Evidence Broker really answers: 53
# requirements, 687 declarations, 22 procedure codes, 27 countries.
RSpec.describe 'Admin::CommonServices::Procedures' do
  let(:answer) { common_services_answer('eb_requirements_catalogue') }

  before do
    sign_in
    stub_code_list
    stub_directory_resolution
    stub_directory_body('eb', 'requirements-by-procedure', *answer)
  end

  describe 'GET /admin/common_services/procedures' do
    it 'lists the procedure codes member states have declared, and what they are called' do
      get admin_common_services_procedures_path

      expect(response.parsed_body.css('.fr-card').size).to eq(22)
      expect(response.body).to include('22 résultats')
      expect(response.parsed_body.css('.fr-card__title').map(&:text).join)
        .to include('R1 — Demander une attestation')
    end

    # A name is an ornament: the page says what it says without one, and the
    # code list lives on a host of its own.
    it 'lists them all the same when the code list cannot be read' do
      stub_request(:get, CodeListClient::PROCEDURES).to_timeout

      get admin_common_services_procedures_path

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.css('.fr-card').size).to eq(22)
      titles = response.parsed_body.css('.fr-card__title').map { |title| title.text.strip }

      expect(titles).to include('00 — Aucun label')
    end

    it 'leads from each code to what is declared under it' do
      get admin_common_services_procedures_path

      expect(response.parsed_body.css("a[href='#{admin_common_services_procedure_path('R1')}']")).to be_present
    end

    # Twenty-two codes fit on one page, so the narrowing happens in the browser
    # rather than by a round trip per keystroke.
    it 'hands the whole catalogue to a search box rather than filtering server-side' do
      get admin_common_services_procedures_path

      search = response.parsed_body.css('input[data-filter]').first

      expect(search['data-filter']).to eq('#liste-demarches > *')
      expect(response.parsed_body.css('#liste-demarches > *').size).to eq(22)
    end

    # The browser rewrites the tally and has no French of its own: the plural
    # forms travel from `fr.yml` in an attribute.
    it 'carries the plural forms of its tally' do
      get admin_common_services_procedures_path

      forms = JSON.parse(response.parsed_body.css('#decompte-demarches').attr('data-tally').value)

      expect(forms).to eq('0' => 'Aucun résultat', '1' => 'Un résultat', 'other' => 'COUNT résultats')
    end
  end

  describe 'GET /admin/common_services/procedures/:code' do
    # One card per country, because what an operator compares is countries:
    # the same code demands something different in each.
    it 'shows one card per country declaring that code' do
      get admin_common_services_procedure_path('R1')

      expect(response.parsed_body.css('h1').text).to include('R1')
      expect(response.body).to include('Demander une attestation')
      countries = response.parsed_body.css('.fr-card__title').map { |title| title.text.strip }

      expect(countries).to eq(countries.uniq)
      expect(countries.size).to be > 1
      expect(countries).to include('🇩🇪 Allemagne (DE)')
    end

    # The preposition follows the article the code list publishes, never a rule
    # guessed on the name.
    it 'names each country the way its article demands' do
      stub_code_list(countries: {
        'DE' => 'Allemagne (l’)', 'LU' => 'Luxembourg (le)',
        'NL' => 'Pays-Bas (les)', 'CY' => 'Chypre',
      })

      get admin_common_services_procedure_path('R1')
      said = response.parsed_body.css('.fr-card__desc').map { |desc| desc.text.strip }

      expect(said).to include(a_string_including('par l’Allemagne'))
      expect(said).to include(a_string_including('par le Luxembourg'))
      expect(said).to include(a_string_including('par les Pays-Bas'))
      expect(said).to include(a_string_including('par Chypre'))
    end

    it 'counts what each country demands to prove, and leads to it' do
      get admin_common_services_procedure_path('R1')

      expect(response.parsed_body.css('.fr-card__desc').first.text).to match(/exigences?/)
      expect(response.parsed_body.css("a[href*='/admin/common_services/procedures/R1/countries/']")).to be_present
    end

    # One country deeper: this is the only level that shows requirements, a
    # procedure demanding the same nowhere.
  end

  describe 'GET /admin/common_services/procedures/:code/country/:country_code' do
    # A page of its own rather than a filter, and the only level that shows
    # requirements: a procedure demands the same nowhere.
    it 'shows what that country demands to prove, in cards and not in a table' do
      get admin_common_services_procedure_country_path('00', 'FR')

      expect(response.parsed_body.css(".fr-card__title a[href^='/admin/common_services/requirements/']")).to be_present
      expect(response.parsed_body.css('table')).to be_empty
      expect(response.parsed_body.css('.fr-text--lead').text).to include('France (FR)')
    end

    # A country publishes several declarations resting on one requirement more
    # often than not — Lithuania files 78 for 52 requirements under `T1` — and
    # counting declarations here would contradict the page one arrives from.
    it 'counts and shows requirements, not the declarations resting on them' do
      get admin_common_services_procedure_country_path('T1', 'LT')
      counted = response.parsed_body.css('.fr-card').size

      get admin_common_services_procedure_path('T1')
      announced = response.parsed_body.css('.fr-card')
        .find { |card| card.css('.fr-card__title').text.strip.end_with?('LT') }

      expect(announced.text).to include("#{counted} exigences")
    end

    it 'says so rather than showing nothing when a country declared nothing' do
      get admin_common_services_procedure_country_path('00', 'ZZ')

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Aucune déclaration de cette démarche dans ce pays')
    end

    it 'answers 404 for a code no member state declared' do
      get admin_common_services_procedure_country_path('ZZ99', 'FR')

      expect(response).to have_http_status(:not_found)
    end

    it 'answers 404 for a code no member state declared' do
      get admin_common_services_procedure_path('ZZ99')

      expect(response).to have_http_status(:not_found)
    end
  end

  # A named refusal is an answer: the directory understood the question and
  # says it holds nothing. The page shows it, with its code.
  context 'when the directory refuses' do
    let(:answer) { common_services_answer('eb_requirements_vides') }

    it 'renders the refusal as a page, with its code' do
      get admin_common_services_procedures_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('EB:ERR:0001')
    end
  end

  # An outage is not an answer, and must not read as one.
  it 'answers 502 when the directory cannot be reached' do
    stub_request(:get, "#{DirectoryStubs::ACCEPTANCE}/eb/rest/search")
      .with(query: hash_including({})).to_timeout

    get admin_common_services_procedures_path

    expect(response).to have_http_status(:bad_gateway)
    expect(response.body).to include('Annuaire injoignable')
  end
end
