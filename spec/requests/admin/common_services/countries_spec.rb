require 'rails_helper'

# Read against the whole catalogue the Evidence Broker really answers: 53
# requirements, 687 declarations, 22 procedure codes, 27 countries.
RSpec.describe 'Admin::CommonServices::Countries' do
  before do
    sign_in
    stub_code_list
    stub_directory_resolution
    stub_directory_body('eb', 'requirements-by-procedure', *common_services_answer('eb_requirements_catalogue'))
  end

  describe 'GET /admin/common_services/countries' do
    it 'lists the jurisdictions that declared anything, and how much each declared' do
      get admin_common_services_countries_path

      expect(response.parsed_body.css('.fr-card').size).to eq(27)
      expect(response.body).to include('27 résultats')
      expect(response.parsed_body.css('input[data-filter]').first['data-filter']).to eq('#liste-pays > *')
    end

    # Read by what a reader sees rather than by the code behind it, this page
    # having nothing else to order itself on.
    it 'orders them on the name it shows' do
      get admin_common_services_countries_path

      named = response.parsed_body.css('.fr-card__title').map { |title| title.text.strip.sub(/\A\S+\s/, '') }

      expect(named).to eq(named.sort)
      expect(named).to include('Allemagne (DE)', 'Finlande (FI)', 'France (FR)')
    end

    # The two roles part here: what a country requires, and what it can prove.
    # The tally exists on the first side alone.
    it 'leads from each country to each of the two roles it holds' do
      get admin_common_services_countries_path

      expect(response.parsed_body.css("a[href='#{admin_common_services_country_procedures_path('FR')}']")).to be_present
      expect(response.parsed_body.css("a[href='#{admin_common_services_country_requirements_path('FR')}']"))
        .to be_present
    end
  end

  describe 'GET /admin/common_services/countries/:code/requirements' do
    before { stub_directory('eb', 'evidence-types-by-requirement', 'eb_evidence_types_fr') }

    # The Evidence Broker has no query that starts from a country: its own takes
    # one requirement at a time, so the page sweeps them all.
    it 'sweeps the catalogue to find what that country publishes' do
      get admin_common_services_country_requirements_path('FR')

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.css('#exigences-satisfaites > *')).not_to be_empty
      expect(response.body).to include('FR - Test Evidence Type')
    end

    # Naming no country: the twenty-seven country pages then share the same
    # cached responses, where a `country-code` would make twenty-seven sets.
    it 'asks the directory without naming the country it narrows on' do
      get admin_common_services_country_requirements_path('FR')

      expect(a_request(:get, "#{DirectoryStubs::ACCEPTANCE}/eb/rest/search")
        .with(query: hash_including('country-code' => 'FR',
          'requirement-id' => a_string_including('requirements')))).not_to have_been_made
    end

    it 'shows nothing for a country that publishes nothing' do
      get admin_common_services_country_requirements_path('LT')

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.css('#exigences-satisfaites > *')).to be_empty
    end

    # This page announces what a country publishes, and counts it. A declaration
    # of non-delivery says the opposite, so it belongs to neither the listing
    # nor the tally — and the tally is read without opening a single card. The
    # declaration has its page, the requirement's.
    context 'when the country declares it issues nothing' do
      before do
        stub_directory_signature
        stub_directory_body('eb', 'evidence-types-by-requirement', evidence_types_declaring_no_match)
      end

      it 'neither lists the requirement nor counts it among those it satisfies' do
        get admin_common_services_country_requirements_path('FR')

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body.css('#exigences-satisfaites > *')).to be_empty
        expect(response.body).not_to include('Ce pays déclare ne délivrer aucun justificatif')
        expect(response.parsed_body.css('#aucune-exigence-satisfaite').attr('hidden')).to be_nil
      end
    end

    # Only the empty result set is a result of the sweep. Any other refusal is
    # the page's, since swallowing it would drop a requirement from the listing
    # for a reason that is not "this country publishes nothing".
    context 'when the directory refuses for another reason than an empty set' do
      before do
        stub_directory_signature
        stub_directory_body('eb', 'evidence-types-by-requirement', refusing_with('EB:ERR:0002'))
      end

      it 'shows the refusal rather than a listing short of one requirement' do
        get admin_common_services_country_requirements_path('FR')

        expect(response.body).to include('EB:ERR:0002')
        expect(response.parsed_body.css('#exigences-satisfaites > *')).to be_empty
      end

      def refusing_with(code)
        common_services_answer('eb_requirements_vides').first.sub('EB:ERR:0001', code)
      end
    end
  end

  describe 'GET /admin/common_services/countries/:code/procedures' do
    it 'lists the procedures that country declared, and what each makes it require' do
      stub_code_list(procedures: { 'V1' => 'Faire enregistrer un changement d’adresse' })

      get admin_common_services_country_procedures_path('FR')

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.css('.fr-card__title').map { |title| title.text.strip })
        .to include('V1 — Faire enregistrer un changement d’adresse')
    end

    # The same declarations, counted the same way as on the procedure's own
    # page: a country files several declarations resting on one requirement.
    it 'counts requirements, not the declarations resting on them' do
      get admin_common_services_country_procedures_path('LT')
      announced = response.parsed_body.css('.fr-card')
        .find { |card| card.css('.fr-card__title').text.strip.start_with?('T1') }

      get admin_common_services_country_procedure_path('LT', 'T1')

      expect(announced.text).to include("#{response.parsed_body.css('.fr-card').size} exigences")
    end

    it 'leads from each procedure to what that country requires under it' do
      get admin_common_services_country_procedures_path('FR')

      expect(response.parsed_body.css("a[href='#{admin_common_services_country_procedure_path('FR', 'V1')}']"))
        .to be_present
    end
  end

  # The same page is reached from a procedure too, and neither descent rewrites
  # the path the reader walked.
  describe 'GET /admin/common_services/countries/:code/procedures/:procedure_code' do
    it 'shows what that country requires, under the trail it was reached by' do
      get admin_common_services_country_procedure_path('FR', 'V1')

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.css('.fr-breadcrumb__link').map(&:text))
        .to eq(['Espace d’administration', 'Annuaires centraux', 'Pays', '🇫🇷 France (FR)', 'Démarches', 'V1'])
    end

    it 'shows the same declarations as the descent from the procedure' do
      get admin_common_services_country_procedure_path('FR', 'V1')
      from_country = response.parsed_body.css('.fr-card__title').map(&:text)

      get admin_common_services_procedure_country_path('V1', 'FR')

      expect(response.parsed_body.css('.fr-card__title').map(&:text)).to eq(from_country)
      expect(response.parsed_body.css('.fr-breadcrumb__link').map(&:text)).to include('Démarches')
    end

    it 'answers 404 for a code no member state declared' do
      get admin_common_services_country_procedure_path('FR', 'ZZ99')

      expect(response).to have_http_status(:not_found)
    end

    # `country-code` names the requester on the requirements query and the
    # provider on the evidence-types one (chapter 3.2.4): carrying the country
    # of this page into the next would silently swap its role, and hide the
    # very thing OOTS exists for — the proof comes from wherever it is held.
    it 'leads from each requirement to what satisfies it everywhere, not in this country' do
      get admin_common_services_country_procedure_path('LT', 'R1')

      expect(response.parsed_body.css("a[href^='/admin/common_services/requirements/']")).to be_present
      expect(response.parsed_body.css("a[href^='/admin/common_services/countries/LT/requirements/']")).to be_empty
    end

    it 'says which of the two roles this country holds here' do
      get admin_common_services_country_procedure_path('LT', 'R1')

      expect(response.body).to include('requêteur')
    end
  end
end
