require 'rails_helper'

RSpec.describe 'Admin::Demo::Documents' do
  include ActiveSupport::Testing::TimeHelpers

  # The one requirement `eb_requirements_fr` holds, and the two of
  # `eb_requirements_t1_fr`, which is the procedure of the demonstration.
  let(:exigence) { '00000000-0000-0000-0000-000000000000' }
  let(:premiere) { 'ffffffff-ffff-ffff-ffff-ffffffffffff' }
  let(:seconde) { '2d21a531-d30e-4e30-9e5e-b53d6aedb30b' }

  before do
    sign_in
    identify_demo_user
    stub_code_list
    stub_directory_resolution
    stub_directory('eb', 'requirements-by-procedure', 'eb_requirements_fr')
    stub_directory('eb', 'evidence-types-by-requirement', 'eb_evidence_types_fi')
    stub_directory('dsd', 'dataservices-by-evidencetype', 'dsd_data_services_fi')
  end

  describe 'GET /admin/demo/documents' do
    # CA2, and requirement 27 of chapter 1 §2 word for word: « The user is
    # provided with information about name of evidence provider and evidence
    # type for confirmation, before any request is made. »
    it 'names the evidence provider and the evidence type the resolution returns' do
      get admin_demo_documents_path(version: 'v2.0')

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.css('main').text).to include('Keha v. 2.0', 'Dummy PDF - FI')
    end

    # A portal's own sentences and the words Brussels publishes read alike on a
    # screen: these two are the directories', and the page says so.
    it 'marks those two as published by the directories, and the identity not' do
      get admin_demo_documents_path(version: 'v2.0')

      marked = response.parsed_body.css('main .directory-value').map { |value| seen(value) }

      expect(marked).to contain_exactly('(TEST) Test Requirement', 'Dummy PDF - FI', 'Keha v. 2.0')
    end

    it 'asks the contract nothing: nothing is opened by looking at the page' do
      get admin_demo_documents_path(version: 'v2.0')

      expect(a_request(:get, "#{Settings.oots_france_url}/requete/pieceJustificative")
        .with(query: hash_including({}))).not_to have_been_made
    end

    # The resolution walks the chain a request walks: the procedure is asked at
    # home, the evidence types in the country the evidence is sought in — the
    # deployment's own until the user picks another.
    it 'asks about the study financing procedure in France' do
      get admin_demo_documents_path(version: 'v2.0')

      expect(a_request(:get, "#{DirectoryStubs::ACCEPTANCE}/eb/rest/search")
        .with(query: hash_including('procedure-id' => 'T1', 'country-code' => 'FR'))).to have_been_made
    end

    # Chapter 2.2 §2 makes the portal answerable for the identity in the request
    # matching the one the eID means yielded, so the page shows it and offers no
    # field on it.
    it 'shows the identity the authentication attested, and offers no field on it' do
      get admin_demo_documents_path(version: 'v2.0')

      card = response.parsed_body.at_css('main .identity-card')
      rows = card.css('dl > div').to_h { |pair| [pair.at_css('dt').text.squish, pair.at_css('dd').text.squish] }

      expect(rows).to include('Family name' => 'Sørensen', 'Given name(s)' => 'Freja Marie')
      expect(card.css('.identity-card__level').text.squish).to eq('Level of assurance: Substantial')
      expect(card.css('input, select, textarea')).to be_empty
    end

    # CA10: the demonstration is the same from either card — the same identity
    # shown, the same requirements, the same request zones. Which FranceConnect+
    # attested is held in the session and said nowhere on this page.
    it 'shows the same page whichever FranceConnect+ attested the identity' do
      get admin_demo_documents_path(version: 'v2.0')
      by_the_fake = response.parsed_body.at_css('main').text.squish

      identify_demo_user(instance: real_france_connect)
      get admin_demo_documents_path(version: 'v2.0')

      expect(response.parsed_body.at_css('main').text.squish).to eq(by_the_fake)
    end

    # The `sub` is a pseudonym of FranceConnect+'s own, per service provider:
    # showing it beside a missing eIDAS identifier would invite taking it for
    # one.
    it 'never shows the pseudonym FranceConnect+ handed this service provider' do
      get admin_demo_documents_path(version: 'v2.0')

      expect(response.body).not_to include(FranceConnectStubs::DANISH_USERINFO.fetch('sub'))
    end

    # Unable to name the two, it must not offer to confirm: requirement 27 makes
    # them a condition of the request, not a decoration on it. The card stays
    # all the same — a requirement no country serves is still one the procedure
    # rests on — and it is the footer that says so, in the portal's own words:
    # the code the directory returned belongs to the console, not here.
    it 'keeps the card and says in its footer that nothing is published' do
      stub_directory('dsd', 'dataservices-by-evidencetype', 'dsd_aucun_service_fr')

      get admin_demo_documents_path(version: 'v2.0')

      carte = response.parsed_body.at_css('main .requirement-card')

      expect(seen(carte.at_css('h3'))).to eq('(TEST) Test Requirement')
      expect(carte.at_css('.fr-card__desc').text.squish).to eq('Evidence impossible to satisfy by 🇫🇷 France (FR)')
      expect(carte.at_css('.requirement-card__actions').text.squish)
        .to eq('⚠️No provider listed by France for this evidence')
      expect(carte.at_css('.fr-card__desc .country-tag')).to be_present
      expect(carte.classes).to include('requirement-card--unsatisfiable')
      expect(response.parsed_body.css("form[action='#{admin_demo_demande_path(version: 'v2.0')}']")).to be_empty
    end

    # A directory that refuses carries a code and raises nothing: the page keeps
    # its section and says what is known — nothing was listed — rather than
    # standing under a heading followed by nothing.
    it 'says that nothing was listed when the Evidence Broker refuses' do
      stub_directory('eb', 'requirements-by-procedure', 'eb_requirements_vides')

      get admin_demo_documents_path(version: 'v2.0')

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.css('main .requirement-card')).to be_empty
      expect(response.parsed_body.css('main').text).to include('listed no evidence for this procedure')
    end

    # « No provider listed » is what `DSD:ERR:0001` — `DS_NOT_FOUND` — says; any
    # other refusal is a directory declining to answer, and the card must not
    # turn that into a statement about what France publishes. Built from the
    # capture rather than captured: the acceptance environment answers no such
    # refusal to ask for, and a retouched fixture would break the signature its
    # `.headers` carries.
    it 'says the country could not answer when the refusal is not a missing entry' do
      refused, = common_services_answer('dsd_aucun_service_fr')
      stub_directory_signature
      stub_directory_body('dsd', 'dataservices-by-evidencetype', refused.sub('DSD:ERR:0001', 'DSD:ERR:0003'))

      get admin_demo_documents_path(version: 'v2.0')

      expect(response.parsed_body.at_css('main .requirement-card__actions').text.squish)
        .to eq('⚠️France could not answer for this evidence')
    end

    # One card per requirement the procedure rests on, each naming its own
    # evidence type and provider.
    it 'offers a card per requirement the procedure rests on' do
      stub_directory('eb', 'requirements-by-procedure', 'eb_requirements_t1_fr')

      get admin_demo_documents_path(version: 'v2.0')

      titres = response.parsed_body.css('main .requirement-card h3').map { |titre| seen(titre) }

      expect(titres).to eq(['(TEST) Test Requirement 2', 'Proof of enrolment in academic tertiary education'])
    end

    # The jurisdiction the documents would come from, named on the card as the
    # directory pages name one: a requirement is satisfied somewhere, and
    # « somewhere » is a country.
    it 'names the country the documents would be requested in' do
      get admin_demo_documents_path(version: 'v2.0')

      contenu = response.parsed_body.at_css('main .requirement-card .fr-card__desc')

      expect(contenu.text.squish).to eq('Satisfied by the following documents in 🇫🇷 France (FR)')
      expect(contenu.at_css('.country-tag')).to be_present
    end

    # The code list names the countries, and it is read like every other: a
    # reading that yields nothing costs the names and never the page. Read on
    # the card that has no provider to name, the one place the country is said
    # in words rather than shown in its box.
    it 'stands on the code alone when the code list names no country' do
      stub_code_list(country_names: {})
      stub_directory('dsd', 'dataservices-by-evidencetype', 'dsd_aucun_service_fr')

      get admin_demo_documents_path(version: 'v2.0')

      carte = response.parsed_body.at_css('main .requirement-card')

      expect(carte.at_css('.fr-card__desc .country-tag').text.squish).to eq('🇫🇷 FR')
      expect(carte.at_css('.requirement-card__actions').text.squish)
        .to eq('⚠️No provider listed by FR for this evidence')
    end

    # CA9. Each card carries its own button and its own zone, and the address
    # tells them apart: chapter 4.4 §4.2.2 has « different basic flows …
    # executed sequentially and/or in parallel », so nothing here makes one card
    # wait on another.
    it 'carries a button and a zone on every card it can name, each on its own address' do
      stub_directory('eb', 'requirements-by-procedure', 'eb_requirements_t1_fr')

      get admin_demo_documents_path(version: 'v2.0')

      cartes = response.parsed_body.css('main .requirement-card')

      expect(cartes.css('.demo-request__body').size).to eq(2)
      expect(cartes.css('button').map { |bouton| bouton.text.squish }).to eq(['Request the document'] * 2)
      expect(cartes.css('[data-controller="demo-request"]').pluck('data-demo-request-url-value'))
        .to eq([admin_demo_demande_path(exigence: premiere, version: 'v2.0'), admin_demo_demande_path(exigence: seconde, version: 'v2.0')])
    end

    # CA8. Requirement 27 makes the two names a condition of the request, so a
    # requirement the country serves with nothing carries neither button nor
    # zone — and its neighbours keep theirs.
    it 'leaves a requirement the country does not serve without button or zone' do
      stub_directory('eb', 'requirements-by-procedure', 'eb_requirements_t1_fr')
      stub_directory('eb', 'evidence-types-by-requirement', 'eb_requirements_vides', requirement: seconde_id)

      get admin_demo_documents_path(version: 'v2.0')

      cartes = response.parsed_body.css('main .requirement-card')

      expect(cartes.size).to eq(2)
      expect(cartes.first.css('.demo-request__body')).to be_present
      expect(cartes.last.css('.demo-request__body')).to be_empty
      expect(cartes.last.text).to include('No provider listed by France for this evidence')
    end

    # Une panne d'annuaire n'est pas un refus : elle ne porte aucun code, et
    # `DirectoryLookup::Refusing` la relève. Le contrôleur la rend comme les
    # pages d'annuaire voisines, et l'exigence 27 interdit alors d'offrir de
    # confirmer quoi que ce soit.
    it 'says so, and offers nothing to confirm, when the directories cannot be reached' do
      stub_request(:get, "#{DirectoryStubs::ACCEPTANCE}/eb/rest/search").with(query: hash_including({})).to_timeout

      get admin_demo_documents_path(version: 'v2.0')

      expect(response).to have_http_status(:bad_gateway)
      expect(response.parsed_body.css('main').text).to include('could not be reached')
      expect(response.parsed_body.css("form[action='#{admin_demo_demande_path(version: 'v2.0')}']")).to be_empty
    end

    it 'sends an operator holding no identity back to the start' do
      reset_session_identity

      get admin_demo_documents_path(version: 'v2.0')

      expect(response).to redirect_to(admin_demo_root_path)
    end

    # The other half of the same condition, and the one an identity alone would
    # hide: the journey names the conversation every request of this walk goes
    # out under, and says which requests the page may report on. A session
    # holding one without the other was written under a shape this code no
    # longer reads.
    it 'sends an operator holding no journey back to the start, identity or no identity' do
      allow(Demo::Journey).to receive(:from_session).and_return(nil)

      get admin_demo_documents_path(version: 'v2.0')

      expect(response).to redirect_to(admin_demo_root_path)
    end
  end

  # The line the journey plays, chosen before the identification: the pages
  # of the walk live under it, and a provider whose gateway does not announce it
  # offers no button.
  describe 'the line of the journey' do
    it 'names a provider that does not support 1.2, and offers no button to ask it' do
      identify_demo_user(version: 'v1.2')

      get admin_demo_documents_path(version: 'v1.2')

      carte = response.parsed_body.at_css('main .requirement-card')
      expect(carte.text).to include('Keha v. 2.0', 'This provider does not support OOTS 1.2')
      expect(carte.css('button, .demo-request')).to be_empty
      expect(carte.at_css('select')).to be_present
    end

    # One crumb per segment of the address.
    it 'hangs its trail on the segments of its address' do
      get admin_demo_documents_path(version: 'v2.0')

      expect(response.parsed_body.css('.fr-breadcrumb__link').map { |crumb| crumb.text.squish })
        .to eq(['Espace d’administration', 'Démo', '2.0', 'Your documents'])
    end

    it 'offers the button on the same card in 2.0' do
      get admin_demo_documents_path(version: 'v2.0')

      expect(response.parsed_body.at_css('main .requirement-card').text).not_to include('does not support')
      expect(response.parsed_body.css('main .requirement-card button').size).to eq(1)
    end

    it 'sends a page of the other line back to the screen the line is chosen on' do
      identify_demo_user(version: 'v1.2')

      get admin_demo_documents_path(version: 'v2.0')
      expect(response).to redirect_to(admin_demo_root_path)

      get admin_demo_demande_path(exigence:, version: 'v2.0')
      expect(response).to redirect_to(admin_demo_root_path)
    end

    # A new identification opens a new journey, in the line of the page it left
    # from, and every card starts again where a first one would.
    it 'plays the other line once identified anew from its sign-in page' do
      identify_demo_user(version: 'v1.2')
      patch admin_demo_pays_path(exigence:, version: 'v1.2'), params: { pays: 'FI' }

      identify_demo_user(version: 'v2.0')

      expect(response).to redirect_to(admin_demo_documents_path(version: 'v2.0'))
      get admin_demo_documents_path(version: 'v2.0')
      carte = response.parsed_body.at_css('main .requirement-card')
      expect(carte.at_css('select option[selected]')['value']).to eq('FR')
      expect(carte.css('button').size).to eq(1)
    end
  end

  # Step 16 of chapter 1 §10.1: « The sample Portal asks the user to specify
  # from which Member State the evidence is to be requested. » The doubled
  # directories answer by the `country-code` they receive: France and Finland
  # both publish a type and a provider — what the specs have France publish is
  # the Finnish capture, and nothing is made up —, Germany publishes nothing,
  # and Austria's Data Service Directory refuses with `DSD:ERR:0001`.
  describe 'the member state each card asks' do
    before do
      stub_directory('eb', 'evidence-types-by-requirement', 'eb_requirements_vides', country: 'DE')
      stub_directory('dsd', 'dataservices-by-evidencetype', 'dsd_aucun_service_fr', country: 'AT')
    end

    # CA1.
    it 'offers the thirty countries of the list without EU, France selected, sorted by name' do
      get admin_demo_documents_path(version: 'v2.0')

      choix = carte.at_css('select')
      options = choix.css('option')

      expect(carte.at_css("label[for='#{choix['id']}']").text.squish).to eq('Country to request the document from')
      expect(options.size).to eq(30)
      expect(options.pluck('value')).not_to include('EU')
      expect(options.find { |option| option['selected'] }['value']).to eq('FR')
      expect(options.map(&:text).first(3)).to eq(['🇦🇹 AT', '🇧🇪 BE', '🇧🇬 BG'])
      expect(options.map(&:text)).to include('🇫🇮 Finland (FI)', '🇬🇷 EL')
      expect(carte.at_css('.fr-card__desc').text.squish).to eq('Satisfied by the following documents in 🇫🇷 France (FR)')
    end

    # CA2 and RG6: changing the country asks the directories alone.
    it 'resolves the card in the chosen country, and asks nothing of the contract' do
      choose_country('FI')
      get admin_demo_documents_path(version: 'v2.0')

      expect(eb_asked('evidence-types-by-requirement', 'FI')).to have_been_made.at_least_once
      expect(dsd_asked('FI')).to have_been_made.at_least_once
      expect(a_request(:get, "#{DirectoryStubs::ACCEPTANCE}/eb/rest/search")
        .with(query: hash_including('queryId' => a_string_including('requirements-by-procedure'),
          'country-code' => 'FR'))).to have_been_made.at_least_once
      expect(carte.at_css('.fr-card__desc').text.squish)
        .to eq('Satisfied by the following documents in 🇫🇮 Finland (FI)')
      expect(carte.text).to include('Dummy PDF - FI', 'Keha v. 2.0')
      expect(carte.at_css('select option[selected]')['value']).to eq('FI')
      expect(contract_demands).to be_empty
    end

    # The browser splices the answer into the card around the list: a fragment
    # it can tell is ours, the card alone, resolved in the country chosen.
    it 'answers the card alone, resolved in the country chosen' do
      choose_country('FI')

      fragment = response.parsed_body

      expect(response.headers['Deferred-Fragment']).to eq('1')
      expect(fragment.css('header, footer, nav')).to be_empty
      expect(fragment.at_css("#exigence-#{exigence} .fr-card__desc").text.squish)
        .to eq('Satisfied by the following documents in 🇫🇮 Finland (FI)')
      expect(fragment.at_css('select option[selected]')['value']).to eq('FI')
      expect(contract_demands).to be_empty
    end

    # What the card names now is what its button sends: the click after the
    # choice goes out with the names of that country, without a reload between.
    it 'has the button send what the card now names' do
      stub_oots_france_public_keys
      stub_evidence_request
      stub_exchange_state
      get admin_demo_documents_path(version: 'v2.0')
      choose_country('FI')
      post demande_path

      expect(evidence_request_query['codePays']).to eq('FI')
      expect(Demo::Request.sole.country_code).to eq('FI')
    end

    # No fragment, so the card says it could not reach the service — one
    # sentence for every cause — and the log keeps which cause it was.
    it 'answers no fragment, and logs why, when the directories cannot be reached' do
      stub_request(:get, "#{DirectoryStubs::ACCEPTANCE}/eb/rest/search").with(query: hash_including({})).to_timeout
      allow(Rails.logger).to receive(:warn)

      choose_country('FI')

      expect(response).to have_http_status(:bad_gateway)
      expect(response.headers['Deferred-Fragment']).to be_nil
      expect(Rails.logger).to have_received(:warn).with(a_string_including('Annuaires injoignables'))
    end

    it 'refuses a requirement the procedure does not rest on' do
      choose_country('FI', 'abababab-abab-abab-abab-abababababab')

      expect(response).to have_http_status(:unprocessable_content)
    end

    # CA3.
    it 'says the card unsatisfiable by a country that publishes nothing, and still offers the choice' do
      choose_country('DE')
      get admin_demo_documents_path(version: 'v2.0')

      expect(carte.at_css('.fr-card__desc').text.squish).to eq('Evidence impossible to satisfy by 🇩🇪 Germany (DE)')
      expect(carte.at_css('.requirement-card__actions').text.squish)
        .to eq('⚠️No provider listed by Germany for this evidence')
      expect(carte.css('.demo-request')).to be_empty
      expect(carte.at_css('select option[selected]')['value']).to eq('DE')
    end

    it 'says the same when the Data Service Directory of the country lists no service' do
      choose_country('AT')
      get admin_demo_documents_path(version: 'v2.0')

      expect(carte.at_css('.requirement-card__actions').text.squish)
        .to eq('⚠️No provider listed by AT for this evidence')
      expect(carte.css('.demo-request')).to be_empty
      expect(carte.at_css('select option[selected]')['value']).to eq('AT')
    end

    # CA8: the page refuses what it never offers, before any directory hears
    # of it.
    %w[XX EU fi].each do |code|
      it "refuses #{code} and asks no directory about it" do
        choose_country(code)

        expect(response).to have_http_status(:unprocessable_content)
        expect(a_request(:get, "#{DirectoryStubs::ACCEPTANCE}/eb/rest/search")
          .with(query: hash_including({}))).not_to have_been_made
      end
    end

    # CA10: the choice of each card is kept, and a reload asks nothing.
    it 'keeps the country chosen on each card across a reload' do
      stub_directory('eb', 'requirements-by-procedure', 'eb_requirements_t1_fr')

      choose_country('DE', seconde)
      choose_country('FI', premiere)
      get admin_demo_documents_path(version: 'v2.0')

      choisis = response.parsed_body.css('main .requirement-card select option[selected]').pluck('value')

      expect(choisis).to eq(%w[FI DE])
      expect(contract_demands).to be_empty
    end

    # What each card names and where it stands live in `demo_cards`, one row per
    # card: the session is a cookie bounded at four kibibytes, which a second
    # card named in it would overflow.
    describe 'on a page of two named cards' do
      before do
        stub_directory('eb', 'requirements-by-procedure', 'eb_requirements_t1_fr')
        # An ID Token as long as the one FranceConnect+ hands back — about 570
        # bytes when measured on 2026-09-29 — without which the cookie would
        # stay under the bound whatever the page wrote in it.
        identify_demo_user(padding: 'x' * 10)
        get admin_demo_documents_path(version: 'v2.0')
      end

      it 'answers the second card resolved in the country chosen on it' do
        choose_country('FI', seconde)

        expect(response).to have_http_status(:ok)
        expect(response.headers['Deferred-Fragment']).to eq('1')
        expect(response.parsed_body.at_css("#exigence-#{seconde} .fr-card__desc").text.squish)
          .to eq('Satisfied by the following documents in 🇫🇮 Finland (FI)')
      end

      it 'keeps neither the names nor the countries in the session, which stays under the bound' do
        expect(session[:demo_identity]['id_token'].bytesize).to be >= 570

        choose_country('FI', premiere)
        choose_country('FI', seconde)

        expect(session.to_h.keys).not_to include('demo_named', 'demo_countries')
        expect(response.headers['Set-Cookie'].to_s[/_oots_france_session=[^;]*/].bytesize).to be < 4096
        expect(Demo::Card.countries(session[:demo_journey]['id'])).to eq(premiere => 'FI', seconde => 'FI')
      end

      # Requirement 27 of chapter 1 §2: what the card showed is what leaves, read
      # back and never resolved anew at the click.
      it 'has the button send what the card named, without asking the directories again' do
        stub_oots_france_public_keys
        stub_evidence_request
        stub_exchange_state
        choose_country('FI', seconde)
        WebMock::RequestRegistry.instance.reset!

        post demande_path(seconde)

        expect(evidence_request_query['codePays']).to eq('FI')
        expect(Demo::Request.sole).to have_attributes(country_code: 'FI', evidence_type_name: 'Dummy PDF - FI',
          provider_name: 'Keha v. 2.0', requirement_uuid: seconde)
        expect(a_request(:get, %r{\A#{DirectoryStubs::ACCEPTANCE}/(eb|dsd)/}o)).not_to have_been_made
      end
    end

    it 'sends back to the page a click on a card the page never named' do
      post demande_path('abababab-abab-abab-abab-abababababab')

      expect(response).to redirect_to(admin_demo_documents_path)
      expect(Demo::Request.count).to eq(0)
    end

    # CA9: a new identification opens a new journey, and the cards start again
    # in the deployment's own country.
    it 'starts every card again in France once the user has identified anew' do
      choose_country('FI')
      previous = session[:demo_journey]['id']
      identify_demo_user

      expect(Demo::Card.where(journey_id: previous)).to be_empty

      get admin_demo_documents_path(version: 'v2.0')

      expect(carte.at_css('select option[selected]')['value']).to eq('FR')
    end

    # What the cards kept goes with the journey; what it asked stays filed.
    it 'keeps the requests of the previous journey' do
      stub_oots_france_public_keys
      stub_evidence_request
      stub_exchange_state
      get admin_demo_documents_path(version: 'v2.0')
      post demande_path

      identify_demo_user

      expect(Demo::Request.count).to eq(1)
    end

    # RG8: a card following a request stays in the country that request went to.
    describe 'on a card following a request' do
      before do
        stub_oots_france_public_keys
        stub_evidence_request
        stub_exchange_state
        choose_country('FI')
        get admin_demo_documents_path(version: 'v2.0')
        post demande_path
      end

      # CA5, first half.
      it 'names the country of the request and offers no choice' do
        get admin_demo_documents_path(version: 'v2.0')

        expect(carte.css('select')).to be_empty
        expect(carte.at_css('.fr-card__desc').text.squish)
          .to eq('Satisfied by the following documents in 🇫🇮 Finland (FI)')
      end

      it 'names it too once the document is in hand' do
        Demo::Request.sole.receive_evidence!("%PDF-1.4\ndrapeau".b)

        get admin_demo_documents_path(version: 'v2.0')

        expect(carte.css('select')).to be_empty
        expect(carte.text).to include('Finland', 'Document retrieved successfully')
      end

      # CA5, second half: a change submitted meanwhile is without effect.
      it 'ignores a change submitted while the request is under way' do
        choose_country('DE')

        expect(response.parsed_body.css('select')).to be_empty
        expect(response.parsed_body.at_css('.fr-card__desc').text.squish)
          .to eq('Satisfied by the following documents in 🇫🇮 Finland (FI)')

        get admin_demo_documents_path(version: 'v2.0')

        expect(carte.at_css('.fr-card__desc').text.squish)
          .to eq('Satisfied by the following documents in 🇫🇮 Finland (FI)')
        expect(eb_asked('evidence-types-by-requirement', 'DE')).not_to have_been_made
      end

      # CA5, last: once the zone offers « Retry to request », the choice is back.
      it 'offers the choice again once the correspondent refused' do
        stub_exchange_state(statut: 'failed')

        get admin_demo_documents_path(version: 'v2.0')

        expect(carte.at_css('select option[selected]')['value']).to eq('FI')
        expect(carte.at_css('.demo-request button').text.squish).to eq('Retry to request')
      end
    end

    # CA6: the request's country on its card, the choice on its neighbour, and
    # a reload opens nothing.
    it 'keeps each card in its own country on a reload' do
      stub_directory('eb', 'requirements-by-procedure', 'eb_requirements_t1_fr')
      stub_oots_france_public_keys
      stub_evidence_request
      stub_exchange_state
      choose_country('FI', premiere)
      get admin_demo_documents_path(version: 'v2.0')
      post demande_path(premiere)
      choose_country('DE', seconde)

      get admin_demo_documents_path(version: 'v2.0')

      cartes = response.parsed_body.css('main .requirement-card')

      expect(cartes.map { |une| une.at_css('.fr-card__desc .country-tag').text.squish })
        .to eq(['🇫🇮 Finland (FI)', '🇩🇪 Germany (DE)'])
      expect(cartes.first.css('select')).to be_empty
      expect(contract_demands.size).to eq(1)
    end

    def carte = response.parsed_body.at_css("main #exigence-#{exigence}")

    def choose_country(code, uuid = exigence) = patch(admin_demo_pays_path(exigence: uuid, version: 'v2.0'), params: { pays: code })

    def eb_asked(query, country)
      a_request(:get, "#{DirectoryStubs::ACCEPTANCE}/eb/rest/search")
        .with(query: hash_including('queryId' => a_string_including(query), 'country-code' => country))
    end

    def dsd_asked(country)
      a_request(:get, "#{DirectoryStubs::ACCEPTANCE}/dsd/rest/search")
        .with(query: hash_including('country-code' => country))
    end
  end

  # Recharger n'est pas redemander : la page rend la zone dans l'état où la
  # session la trouve, et n'ouvre rien. Chapitre 4.4 §4.1 — une nouvelle réponse
  # passe par une nouvelle requête, donc relire est libre.
  describe 'GET /admin/demo/documents, on a journey already under way' do
    before do
      stub_oots_france_public_keys
      stub_evidence_request
      stub_exchange_state
      get admin_demo_documents_path(version: 'v2.0')
      post demande_path
    end

    it 'opens on the waiting rather than on a button that would start a second' do
      get admin_demo_documents_path(version: 'v2.0')

      expect(response.parsed_body.at_css('.demo-request__body')['data-polling']).to eq('true')
      expect(response.parsed_body.css('main').text).to include('Requesting the document')
    end

    it 'opens on the document once it has been filed, and asks the contract nothing more' do
      Demo::Request.sole.receive_evidence!("%PDF-1.4\ndrapeau".b)

      get admin_demo_documents_path(version: 'v2.0')

      expect(response.parsed_body.css('main').text).to include('Document retrieved successfully')
      expect(a_request(:get, "#{Settings.oots_france_url}/requete/pieceJustificative")
        .with(query: hash_including({}))).to have_been_made.once
    end
  end

  # Chapter 4.9 §5: the user comes back by the return address, and the portal
  # « Confirm[s] that the user accessing the Online Procedure Portal using the
  # return URL is the user that is executing the associated procedure ».
  describe 'GET /admin/demo/documents, back from the preview space' do
    let(:echange) { DemoContractStubs::ACCEPTED_EXCHANGE }
    let(:conversation) { DemoContractStubs::ACCEPTED_CONVERSATION }

    before do
      stub_oots_france_public_keys
      stub_evidence_request
      stub_exchange_state(statut: 'preview_required')
      stub_preview_confirmation
      get admin_demo_documents_path(version: 'v2.0')
      post demande_path
      stub_exchange_state(statut: 'pending')
    end

    it 'opens on the departure page until the user comes back' do
      get admin_demo_documents_path(version: 'v2.0')

      expect(response.parsed_body.css('main').text).to include('Preview and approve the document')
    end

    it 'takes the user back to the waiting of the card whose exchange it names' do
      get admin_demo_documents_path(version: 'v2.0', echange:, conversation:)

      expect(Demo::Request.sole.returned_at).to be_present
      expect(response.parsed_body.at_css('.demo-request__body')['data-outcome']).to eq('pending')
      expect(response.parsed_body.css('main').text).to include('Requesting the document')
    end

    it 'ignores an exchange of another walk, and renders the page as it stands' do
      registered_request('aaaaaaaa-0000-4000-8000-000000000009', preview_address: 'https://ap.example/preview')

      get admin_demo_documents_path(version: 'v2.0', echange: 'aaaaaaaa-0000-4000-8000-000000000009', conversation:)

      expect(response).to have_http_status(:ok)
      expect(Demo::Request.where.not(returned_at: nil)).to be_empty
    end

    it 'ignores an exchange named under another conversation' do
      get admin_demo_documents_path(version: 'v2.0', echange:, conversation: 'une-autre')

      expect(Demo::Request.find_by(exchange_id: echange).returned_at).to be_nil
    end

    it 'counts the return once, whatever the reloads' do
      get admin_demo_documents_path(version: 'v2.0', echange:, conversation:)
      first = Demo::Request.find_by(exchange_id: echange).returned_at

      travel(1.minute) { get admin_demo_documents_path(version: 'v2.0', echange:, conversation:) }

      expect(Demo::Request.find_by(exchange_id: echange).returned_at).to eq(first)
    end
  end

  # The session is the operator's, and `Demo::UserIdentity.from_session` answers
  # `nil` to anything it can no longer read.
  def reset_session_identity
    allow(Demo::UserIdentity).to receive(:from_session).and_return(nil)
  end

  def seconde_id = "https://sr.acc.oots.tech.ec.europa.eu/requirements/#{seconde}"

  def demande_path(uuid = exigence) = admin_demo_demande_path(exigence: uuid, version: 'v2.0')
end
