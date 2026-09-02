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
    # The sweep costs one directory query per requirement, so the page arrives
    # without it and comes back for the listing at the address it carries.
    it 'holds a place for the listing rather than sweeping the catalogue to render it' do
      get admin_common_services_requirements_path

      expect(response.parsed_body.css('h1').text).to eq('Exigences')
      expect(response.parsed_body.css('[data-controller="deferred"]').attr('data-deferred-url-value').value)
        .to eq(admin_common_services_requirements_path(listing: 1))
      expect(response.body).to include('Chargement de toutes les exigences publiées')
      expect(a_request(:get, "#{DirectoryStubs::ACCEPTANCE}/eb/rest/search")
        .with(query: hash_including('requirement-id'))).not_to have_been_made
    end

    # What is left to read where nothing goes and fetches the listing.
    it 'says in the page itself that its content needs JavaScript' do
      get admin_common_services_requirements_path

      expect(response.parsed_body.css('noscript').text).to include('charge son contenu en JavaScript')
    end

    # The header is what the browser reads to know the body is ours to splice
    # in, a status being unable to say it — nginx answers `502` out of its own
    # pocket when nothing runs behind it. The page itself never carries it.
    it 'stamps the listing, and only the listing, as ours to splice in' do
      get admin_common_services_requirements_path
      expect(response.headers['Deferred-Fragment']).to be_nil

      get admin_common_services_requirements_path(listing: 1)
      expect(response.headers['Deferred-Fragment']).to eq('1')
    end

    # `render_refusal` is inherited by every controller of this section, so the
    # parameter must not be enough to reach the fragment: appended to a page
    # never written for it, it would answer a refusal with a bare partial —
    # no layout, no stylesheet, no breadcrumb.
    it 'leaves the other pages of the section whole, parameter or not' do
      stub_request(:get, "#{DirectoryStubs::ACCEPTANCE}/eb/rest/search").with(query: hash_including({}))
        .to_timeout

      get admin_common_services_procedures_path(listing: 1)

      expect(response).to have_http_status(:bad_gateway)
      expect(response.parsed_body.css('h1')).to be_present
      expect(response.parsed_body.css('.fr-breadcrumb')).to be_present
    end
  end

  describe 'GET /admin/common_services/requirements?listing=1' do
    # Fifty-three requirements fit on one page, so the narrowing happens in the
    # browser rather than by a round trip per keystroke.
    it 'hands every requirement to a search box rather than filtering server-side' do
      get admin_common_services_requirements_path(listing: 1)

      expect(response.body).to include('53 résultats')
      expect(response.parsed_body.css('#liste-exigences > *').size).to eq(53)
      expect(response.parsed_body.css('input[data-controller="filter"]').first['data-filter-entries-value'])
        .to eq('#liste-exigences > *')
      expect(response.parsed_body.css('.fr-pagination')).to be_empty
    end

    # These countries satisfy the requirement, they do not impose it — which the
    # listing cannot know without one directory query per requirement, the
    # Evidence Broker answering this question for one requirement at a time.
    it 'leads from each country satisfying a requirement to what it publishes for it' do
      get admin_common_services_requirements_path(listing: 1)
      card = response.parsed_body.css('.fr-card').first
      uuid = card.css('.fr-card__title a').attr('href').value.split('/').last

      expect(card.text).to include('Justificatifs publiés par')
      expect(card.text).not_to include('Exigé par des démarches de')
      expect(card.css("a[href='#{admin_common_services_requirement_country_path(uuid, 'FR')}']")).to be_present
      expect(card.css("a[href*='/countries/LT']")).to be_empty
    end

    # A card whose row is missing reads as a section that failed to render,
    # where the page went and asked fifty-three times to be able to say it.
    context 'when nobody publishes for a requirement' do
      before do
        stub_directory_signature
        stub_directory_body('eb', 'evidence-types-by-requirement', evidence_types_declaring_no_match)
      end

      it 'says so on the card rather than leaving it bare' do
        get admin_common_services_requirements_path(listing: 1)
        card = response.parsed_body.css('.fr-card').first

        expect(card.text).to include('Aucun pays ne publie de justificatif')
        expect(card.css('.country-tag-list')).to be_empty
      end
    end

    # The sweep is the page's, not the catalogue's: an operator reading a
    # listing that surprises them must find the query that filled it.
    it 'declares the sweep beside the catalogue query it rests on' do
      get admin_common_services_requirements_path(listing: 1)
      declared = response.parsed_body.css('.fr-accordion code').map(&:text)

      expect(declared).to include(EvidenceBrokerClient::REQUIREMENTS_QUERY,
        EvidenceBrokerClient::EVIDENCE_TYPES_QUERY)
      expect(response.body).to include('chacune des 53 exigences du catalogue')
    end

    # Only an empty result set is a result of the sweep. Any other refusal is
    # the page's, since swallowing it would drop a requirement from the listing
    # for a reason that is not "no country publishes for it".
    context 'when the directory refuses the sweep for another reason than an empty set' do
      before do
        stub_directory_signature
        stub_directory_body('eb', 'evidence-types-by-requirement',
          common_services_answer('eb_requirements_vides').first.sub('EB:ERR:0001', 'EB:ERR:0002'))
      end

      it 'shows the refusal rather than a listing short of one requirement' do
        get admin_common_services_requirements_path(listing: 1)

        expect(response.body).to include('EB:ERR:0002')
        expect(response.parsed_body.css('#liste-exigences > *')).to be_empty
      end

      # The alert takes the place the listing was to fill: the breadcrumb and
      # the heading are already on the reader's screen, and a page would put a
      # second set of them underneath.
      it 'renders the alert alone, where the page has already said where it is' do
        get admin_common_services_requirements_path(listing: 1)

        expect(response).to have_http_status(:ok)
        expect(response.headers['Deferred-Fragment']).to eq('1')
        expect(response.parsed_body.css('h1')).to be_empty
        expect(response.parsed_body.css('.fr-breadcrumb')).to be_empty
        expect(response.parsed_body.css('.fr-alert').text).to include('EB:ERR:0002')
      end
    end

    # An unreachable directory is not a refusal, and the page has already
    # answered `200` without asking anyone: it is this request that carries the
    # `502`, which `deferred_controller.js` is written to inject rather than
    # replace with its own wording.
    context 'when the directory cannot be reached at all' do
      it 'answers 502 with the alert the deferred fetch will show' do
        stub_request(:get, "#{DirectoryStubs::ACCEPTANCE}/eb/rest/search").with(query: hash_including({}))
          .to_timeout

        get admin_common_services_requirements_path(listing: 1)

        expect(response).to have_http_status(:bad_gateway)
        expect(response.headers['Deferred-Fragment']).to eq('1')
        expect(response.body).to include('Annuaire injoignable')
      end
    end

    # The browser rewrites the tally and has no French of its own: the plural
    # forms travel from `fr.yml` in an attribute, and say nothing of what is
    # counted — a search narrows it to something else at every keystroke.
    it 'carries the plural forms of its tally' do
      get admin_common_services_requirements_path(listing: 1)

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
    # read, not followed — the rule the preview location of an exchange
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

    # A declaration published without its code belongs to no procedure: there is
    # nowhere to lead, and the DSFR arrow would promise the opposite.
    context 'when a declaration carries no procedure code' do
      let(:answer) { [unnamed, {}] }

      before { stub_directory_signature }

      it 'lists it without an arrow, since it leads nowhere' do
        get admin_common_services_requirement_procedures_path(test_requirement)
        card = response.parsed_body.css('.fr-card').find { |found| found.css('.fr-card__title').text.strip == '—' }

        expect(card['class']).to include('fr-card--no-arrow')
        expect(card.css('.fr-card__title a')).to be_empty
      end

      # The one Estonian declaration under X4, stripped of the code it carries.
      # `gsub` because the directory republishes the same declaration under each
      # of the requirements it calls on: the first in the file is elsewhere.
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

      # The same declaration, stripped this time of the country that files it —
      # and alone under its code, or the others would fill the footer.
      def stateless
        common_services_answer('eb_requirements_catalogue').first
          .gsub(%r{(54d19e6c[^<]*</sdg:Identifier>.*?<sdg:AdminUnitLevel1>)[^<]*}m, '\\1')
      end
    end
  end

  describe 'GET /admin/common_services/requirements/:requirement_id/countries/:country_code' do
    # The page above narrowed to one provider country, and it is the same
    # answer read twice: the query names no country, so the twenty-seven pages
    # and the requirement's own share what is already cached.
    it 'shows what that country publishes, without asking the directory for it by name' do
      get admin_common_services_requirement_country_path(test_requirement, 'FR')

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('FR - Test Evidence Type', 'fournisseur')
      expect(a_request(:get, "#{DirectoryStubs::ACCEPTANCE}/eb/rest/search")
        .with(query: hash_including('country-code' => 'FR'))).not_to have_been_made
    end

    # One country left to read: a field that narrowed it to itself would be a
    # control with nothing to do, and a tally would count what is already whole.
    it 'offers neither search nor tally, having one country to show' do
      get admin_common_services_requirement_country_path(test_requirement, 'FR')

      expect(response.parsed_body.css('input[data-controller="filter"]')).to be_empty
      expect(response.parsed_body.css('[data-tally]')).to be_empty
    end

    # The same button as the requirement's own page, and to the same place: the
    # other role is one page away wherever one stands.
    it 'leads to what imposes the requirement, as the page above does' do
      get admin_common_services_requirement_country_path(test_requirement, 'FR')

      expect(response.parsed_body.css("a[href='#{admin_common_services_requirement_procedures_path(test_requirement)}']"))
        .to be_present
    end

    it 'leads from each evidence type to the providers that deliver it' do
      get admin_common_services_requirement_country_path(test_requirement, 'FR')

      expect(response.parsed_body.css("a[href*='/evidence_types/'][href$='/providers']")).to be_present
    end

    it 'answers 404 for a country the directory publishes nothing of' do
      get admin_common_services_requirement_country_path(test_requirement, 'ZZ')

      expect(response).to have_http_status(:not_found)
    end

    # No listing leads here for such a country — a `NoMatch` states the very
    # opposite of what those listings announce — and this is the page that says
    # so in as many words, being built around the requirement.
    context 'when the country declares it issues nothing' do
      before do
        stub_directory_signature
        stub_directory_body('eb', 'evidence-types-by-requirement', evidence_types_declaring_no_match)
      end

      it 'renders the declaration rather than an empty page' do
        get admin_common_services_requirement_country_path(test_requirement, 'FR')

        expect(response).to have_http_status(:ok)
        expect(response.body).to include('Ce pays déclare ne délivrer aucun justificatif')
      end

      it 'is not linked from the listing that announces which countries satisfy it' do
        get admin_common_services_requirements_path

        expect(response.parsed_body.css("a[href*='/countries/FR']")).to be_empty
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
