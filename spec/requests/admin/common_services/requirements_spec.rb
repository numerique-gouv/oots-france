require 'rails_helper'

RSpec.describe 'Admin::CommonServices::Requirements' do
  let(:test_requirement) { '00000000-0000-0000-0000-000000000000' }

  let(:answer) { common_services_answer('eb_requirements_catalogue') }

  before do
    sign_in
    stub_code_list
    stub_directory_resolution
    stub_directory_body('eb', 'requirements-by-procedure', *answer)
    stub_directory('eb', 'evidence-types-by-requirement', 'eb_evidence_types_fr')
  end

  describe 'GET /admin/common_services/requirements' do
    # Fifty-three requirements fit on one page, so the narrowing happens in the
    # browser rather than by a round trip per keystroke.
    it 'hands every requirement to a search box rather than filtering server-side' do
      get admin_common_services_requirements_path

      expect(response.body).to include('53 résultats')
      expect(response.parsed_body.css('#liste-exigences > *').size).to eq(53)
      expect(response.parsed_body.css('input[data-filter]').first['data-filter']).to eq('#liste-exigences > *')
      expect(response.parsed_body.css('.fr-pagination')).to be_empty
    end

    # These countries impose the requirement, they do not satisfy it: whom the
    # listing cannot know without one directory query per requirement.
    it 'leads from each country imposing a requirement to what it imposes it under' do
      get admin_common_services_requirements_path
      card = response.parsed_body.css('.fr-card').first
      uuid = card.css('.fr-card__title a').attr('href').value.split('/').last

      expect(card.text).to include('Exigé par des démarches de')
      expect(card.css('.country-tag-list .country-tag').size).to be > 1
      expect(card.css("a[href='#{admin_common_services_requirement_country_path(uuid, 'LT')}']")).to be_present
    end

    # The browser rewrites the tally and has no French of its own: the plural
    # forms travel from `fr.yml` in an attribute, and say nothing of what is
    # counted — a search narrows it to something else at every keystroke.
    it 'carries the plural forms of its tally' do
      get admin_common_services_requirements_path

      forms = JSON.parse(response.parsed_body.css('#decompte-exigences').attr('data-tally').value)

      expect(forms).to eq('0' => 'Aucun résultat', '1' => 'Un résultat', 'other' => 'COUNT résultats')
    end
  end

  describe 'GET /admin/common_services/requirements/:id' do
    it 'shows what the directory says of it, and what satisfies it' do
      get admin_common_services_requirement_path(test_requirement)

      expect(response.parsed_body.css('h1').text).to include('(TEST) Test Requirement')
      expect(response.body).to include('Member States may assign their own Evidence Types')
      expect(response.parsed_body.css('.fr-card').size).to be >= 1
    end

    # The other role is a page of its own: this one answers what satisfies the
    # requirement, from end to end.
    it 'leads to what imposes it rather than listing it here' do
      get admin_common_services_requirement_path(test_requirement)

      expect(response.parsed_body.css("a[href='#{admin_common_services_requirement_procedures_path(test_requirement)}']"))
        .to be_present
      expect(response.body).not_to include('Qui l’impose')
    end

    # The identifier is a Semantic Repository address, chosen elsewhere: it is
    # read, not followed — the rule the preview location of a conversation
    # already follows.
    it 'renders the Semantic Repository identifier as text, never as a link' do
      get admin_common_services_requirement_path(test_requirement)

      expect(response.body).to include("sr.acc.oots.tech.ec.europa.eu/requirements/#{test_requirement}")
      expect(response.parsed_body.css("a[href*='sr.acc.oots.tech.ec.europa.eu']")).to be_empty
    end

    it 'answers 404 for a requirement the directory does not publish' do
      get admin_common_services_requirement_path('00000000-0000-0000-0000-999999999999')

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'GET /admin/common_services/requirements/:requirement_id/procedures' do
    # One card per procedure and not per declaration: dozens of countries
    # declare the same code against one requirement, and it is they that fill
    # the card.
    it 'gathers the countries declaring the same code onto one card' do
      get admin_common_services_requirement_procedures_path(test_requirement)

      codes = response.parsed_body.css('.fr-card__title').map { |title| title.text.strip }
      tags = response.parsed_body.css('.fr-card').map { |card| card.css('.country-tag-list .country-tag').size }

      expect(codes).to eq(codes.uniq)
      expect(tags.max).to be > 1
    end

    it 'leads to the procedure from the card body, and lists the countries under it' do
      get admin_common_services_requirement_procedures_path(test_requirement)
      card = response.parsed_body.css('.fr-card').first

      expect(card['class']).to include('fr-enlarge-link')
      expect(card.css('.fr-card__footer .country-tag-list')).to be_present
      expect(card.css('.fr-card__desc .country-tag-list')).to be_empty
    end

    it 'names the role those countries hold, and leads to what each declares' do
      get admin_common_services_requirement_procedures_path(test_requirement)

      expect(response.body).to include('requêteurs')
      expect(response.parsed_body.css("a[href^='#{admin_common_services_procedure_path('00')}/countries/']"))
        .to be_present
    end

    it 'answers 404 for a requirement the directory does not publish' do
      get admin_common_services_requirement_procedures_path('00000000-0000-0000-0000-999999999999')

      expect(response).to have_http_status(:not_found)
    end

    # Une déclaration publiée sans son code n'appartient à aucune démarche : il
    # n'y a nulle part où mener, et la flèche du DSFR promettrait le contraire.
    context 'when a declaration carries no procedure code' do
      let(:answer) { [unnamed, {}] }

      before { stub_directory_signature }

      it 'lists it without an arrow, since it leads nowhere' do
        get admin_common_services_requirement_procedures_path(test_requirement)
        card = response.parsed_body.css('.fr-card').find { |found| found.css('.fr-card__title').text.strip == '—' }

        expect(card['class']).to include('fr-card--no-arrow')
        expect(card.css('.fr-card__title a')).to be_empty
      end

      # La seule déclaration estonienne sous X4, privée du code qu'elle porte.
      # `gsub` parce que l'annuaire republie la même déclaration sous chacune
      # des exigences qu'elle appelle : la première du fichier est ailleurs.
      def unnamed
        common_services_answer('eb_requirements_catalogue').first
          .gsub(%r{(54d19e6c[^<]*</sdg:Identifier>.*?<sdg:RelatedTo>\s*<sdg:Identifier>)[^<]*}m, '\\1')
      end
    end

    context 'when a declaration publishes no jurisdiction' do
      let(:answer) { [stateless, {}] }

      before { stub_directory_signature }

      it 'says so in the card rather than opening an empty footer' do
        get admin_common_services_requirement_procedures_path(test_requirement)
        card = response.parsed_body.css('.fr-card').find { |found| found.text.include?('X4') }

        expect(card.css('.fr-card__desc').text).to include('Aucun pays publié')
        expect(card.css('.fr-card__footer')).to be_empty
      end

      # La même déclaration, privée cette fois du pays qui la dépose — et seule
      # sous son code, sans quoi les autres rempliraient le pied.
      def stateless
        common_services_answer('eb_requirements_catalogue').first
          .gsub(%r{(54d19e6c[^<]*</sdg:Identifier>.*?<sdg:AdminUnitLevel1>)[^<]*}m, '\\1')
      end
    end
  end

  describe 'GET /admin/common_services/requirements/:requirement_id/countries/:country_code' do
    # The catalogue already carries the declarations: narrowing them to one
    # jurisdiction asks the directory nothing more.
    it 'shows the procedures that country declared it under, and how it names them' do
      get admin_common_services_requirement_country_path(test_requirement, 'LT')

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.css('.fr-card')).not_to be_empty
      expect(response.body).to include('requêteur')
      expect(a_request(:get, "#{DirectoryStubs::ACCEPTANCE}/eb/rest/search")
        .with(query: hash_including('country-code' => 'LT'))).not_to have_been_made
    end

    it 'leads from each procedure to what that country requires under it' do
      get admin_common_services_requirement_country_path(test_requirement, 'LT')

      expect(response.parsed_body.css("a[href*='/procedures/00/countries/LT']")).to be_present
    end

    it 'answers 404 for a country that declared nothing under it' do
      get admin_common_services_requirement_country_path(test_requirement, 'ZZ')

      expect(response).to have_http_status(:not_found)
    end

    # A declaration published without its code belongs to no procedure, so
    # nothing can be counted under it — and asking anyway is how this page
    # answered 500 instead of listing the declarations that do have one.
    context 'when a declaration of that country carries no procedure code' do
      let(:answer) { [unnamed, {}] }

      before { stub_directory_signature }

      it 'lists the others rather than failing' do
        get admin_common_services_requirement_country_path(test_requirement, 'LT')

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body.css('.fr-card')).not_to be_empty
      end

      # One of the six Lithuanian declarations of the test requirement, stripped
      # of the code it maps onto.
      def unnamed
        common_services_answer('eb_requirements_catalogue').first
          .sub(%r{(88330d77[^<]*</sdg:Identifier>.*?<sdg:RelatedTo>\s*<sdg:Identifier>)[^<]*}m, '\\1')
      end
    end

    # What a directory publishes is foreign text, and nothing in the chain
    # renders it as HTML.
    context 'when the directory publishes markup in a name' do
      let(:answer) { [injected, {}] }

      # An altered body no longer matches the signature that came with it, and
      # that check is what would fail first.
      before { stub_directory_signature }

      it 'escapes what the directory publishes' do
        get admin_common_services_requirement_path(test_requirement)

        expect(response.body).not_to include('<script>alert(1)</script>')
        expect(response.body).to include('&lt;script&gt;alert(1)&lt;/script&gt;')
      end

      # Escaped in the answer, so that the directory is publishing the markup
      # as text rather than as elements of its own document — which is what a
      # correspondent filling in a name would produce.
      def injected
        common_services_answer('eb_requirements_catalogue').first.sub(
          '<sdg:Name lang="EN">(TEST) Test Requirement</sdg:Name>',
          '<sdg:Name lang="EN">&lt;script&gt;alert(1)&lt;/script&gt;</sdg:Name>',
        )
      end
    end
  end
end
