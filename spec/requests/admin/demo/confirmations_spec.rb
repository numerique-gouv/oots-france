require 'rails_helper'

RSpec.describe 'Admin::Demo::Confirmations' do
  before do
    sign_in
    identify_demo_user
    stub_code_list
    stub_directory_resolution
    stub_directory('eb', 'requirements-by-procedure', 'eb_requirements_fr')
    stub_directory('eb', 'evidence-types-by-requirement', 'eb_evidence_types_fi')
    stub_directory('dsd', 'dataservices-by-evidencetype', 'dsd_data_services_fi')
  end

  describe 'GET /admin/demo/confirmation' do
    # CA2, and requirement 27 of chapter 1 §2 word for word: « The user is
    # provided with information about name of evidence provider and evidence
    # type for confirmation, before any request is made. »
    it 'names the evidence provider and the evidence type the resolution returns' do
      get admin_demo_confirmation_path

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.css('main').text).to include('Keha v. 2.0', 'Dummy PDF - FI')
    end

    # A portal's own sentences and the words Brussels publishes read alike on a
    # screen: these two are the directories', and the page says so.
    it 'marks those two as published by the directories, and the identity not' do
      get admin_demo_confirmation_path

      marked = response.parsed_body.css('main .directory-value').map { |value| seen(value) }

      expect(marked).to contain_exactly('(TEST) Test Requirement', 'Dummy PDF - FI', 'Keha v. 2.0')
    end

    it 'asks the contract nothing: nothing is opened by looking at the page' do
      get admin_demo_confirmation_path

      expect(a_request(:get, "#{Settings.oots_france_url}/requete/pieceJustificative")
        .with(query: hash_including({}))).not_to have_been_made
    end

    # The resolution walks the chain a request walks: the procedure is asked at
    # home, the evidence types in the country the evidence is sought in — both
    # `FR` here, the demonstration making France talk to France.
    it 'asks about the study financing procedure in France' do
      get admin_demo_confirmation_path

      expect(a_request(:get, "#{DirectoryStubs::ACCEPTANCE}/eb/rest/search")
        .with(query: hash_including('procedure-id' => 'T1', 'country-code' => 'FR'))).to have_been_made
    end

    # Chapter 2.2 §2 makes the portal answerable for the identity in the request
    # matching the one the eID means yielded, so the page shows it and offers no
    # field on it.
    it 'shows the identity the authentication attested, and offers no field on it' do
      get admin_demo_confirmation_path

      card = response.parsed_body.at_css('main .identity-card')
      rows = card.css('dl > div').to_h { |pair| [pair.at_css('dt').text.squish, pair.at_css('dd').text.squish] }

      expect(rows).to include('Family name' => 'Sørensen', 'Given name(s)' => 'Freja Marie')
      expect(card.css('.identity-card__level').text.squish).to eq('Level of assurance: Substantial')
      expect(card.css('input, select, textarea')).to be_empty
    end

    # The `sub` is a pseudonym of FranceConnect+'s own, per service provider:
    # showing it beside a missing eIDAS identifier would invite taking it for
    # one.
    it 'never shows the pseudonym FranceConnect+ handed this service provider' do
      get admin_demo_confirmation_path

      expect(response.body).not_to include(FranceConnectStubs::DANISH_USERINFO.fetch('sub'))
    end

    # Unable to name the two, it must not offer to confirm: requirement 27 makes
    # them a condition of the request, not a decoration on it. The card stays
    # all the same — a requirement no country serves is still one the procedure
    # rests on — and it is the footer that says so, in the portal's own words:
    # the code the directory returned belongs to the console, not here.
    it 'keeps the card and says in its footer that nothing is published' do
      stub_directory('dsd', 'dataservices-by-evidencetype', 'dsd_aucun_service_fr')

      get admin_demo_confirmation_path

      carte = response.parsed_body.at_css('main .requirement-card')

      expect(seen(carte.at_css('h3'))).to eq('(TEST) Test Requirement')
      expect(carte.at_css('.fr-card__desc').text.squish).to eq('Evidence impossible to satisfy by 🇫🇷 France (FR)')
      expect(carte.at_css('.requirement-card__actions').text.squish)
        .to eq('⚠️No provider listed by France for this evidence')
      expect(carte.at_css('.fr-card__desc .country-tag')).to be_present
      expect(carte.classes).to include('requirement-card--unsatisfiable')
      expect(response.parsed_body.css("form[action='#{admin_demo_confirmation_path}']")).to be_empty
    end

    # A directory that refuses carries a code and raises nothing: the page keeps
    # its section and says what is known — nothing was listed — rather than
    # standing under a heading followed by nothing.
    it 'says that nothing was listed when the Evidence Broker refuses' do
      stub_directory('eb', 'requirements-by-procedure', 'eb_requirements_vides')

      get admin_demo_confirmation_path

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

      get admin_demo_confirmation_path

      expect(response.parsed_body.at_css('main .requirement-card__actions').text.squish)
        .to eq('⚠️France could not answer for this evidence')
    end

    # One card per requirement the procedure rests on, each naming its own
    # evidence type and provider.
    it 'offers a card per requirement the procedure rests on' do
      stub_directory('eb', 'requirements-by-procedure', 'eb_requirements_t1_fr')

      get admin_demo_confirmation_path

      titres = response.parsed_body.css('main .requirement-card h3').map { |titre| seen(titre) }

      expect(titres).to eq(['(TEST) Test Requirement 2', 'Proof of enrolment in academic tertiary education'])
    end

    # The jurisdiction the documents would come from, named on the card as the
    # directory pages name one: a requirement is satisfied somewhere, and
    # « somewhere » is a country.
    it 'names the country the documents would be requested in' do
      get admin_demo_confirmation_path

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

      get admin_demo_confirmation_path

      carte = response.parsed_body.at_css('main .requirement-card')

      expect(carte.at_css('.fr-card__desc .country-tag').text.squish).to eq('🇫🇷 FR')
      expect(carte.at_css('.requirement-card__actions').text.squish)
        .to eq('⚠️No provider listed by FR for this evidence')
    end

    # The contract names no requirement and its server answers with the first
    # that publishes evidence types, so a second button would send the same
    # request under another name. Stub, tracked as OOTS-212.
    it 'carries the press on one card only, and says why on the others' do
      stub_directory('eb', 'requirements-by-procedure', 'eb_requirements_t1_fr')

      get admin_demo_confirmation_path

      cartes = response.parsed_body.css('main .requirement-card')

      expect(cartes.css("form[action='#{admin_demo_confirmation_path}']").size).to eq(1)
      expect(cartes.last.text).to include('one document at a time')
    end

    # Une panne d'annuaire n'est pas un refus : elle ne porte aucun code, et
    # `DirectoryLookup::Refusing` la relève. Le contrôleur la rend comme les
    # pages d'annuaire voisines, et l'exigence 27 interdit alors d'offrir de
    # confirmer quoi que ce soit.
    it 'says so, and offers nothing to confirm, when the directories cannot be reached' do
      stub_request(:get, "#{DirectoryStubs::ACCEPTANCE}/eb/rest/search").with(query: hash_including({})).to_timeout

      get admin_demo_confirmation_path

      expect(response).to have_http_status(:bad_gateway)
      expect(response.parsed_body.css('main').text).to include('could not be reached')
      expect(response.parsed_body.css("form[action='#{admin_demo_confirmation_path}']")).to be_empty
    end

    it 'sends an operator holding no identity back to the start' do
      reset_session_identity

      get admin_demo_confirmation_path

      expect(response).to redirect_to(admin_demo_root_path)
    end
  end

  describe 'POST /admin/demo/confirmation' do
    before do
      stub_oots_france_public_keys
      stub_evidence_request
      # The page requirement 27 is satisfied on: a press only exists once it has
      # been shown what it would ask for.
      get admin_demo_confirmation_path
    end

    # CA3: the request goes out through the contract, with the query string a
    # French service provider's server would send.
    it 'asks for the evidence through GET /requete/pieceJustificative' do
      post admin_demo_confirmation_path

      expect(evidence_request_query).to include(
        'codeDemarche' => 'T1', 'codePays' => 'FR',
        'previsualisationRequise' => 'false', 'idRequeteur' => '00000000000003',
      )
    end

    it 'sends a beneficiary token and never the pseudonym FranceConnect+ handed it' do
      post admin_demo_confirmation_path

      expect(evidence_request_query['beneficiaire']).to be_present
      expect(evidence_request_query['beneficiaire']).not_to include(FranceConnectStubs::DANISH_USERINFO.fetch('sub'))
    end

    # A request that left ends the page: the answer appears on the tracking, and
    # that is the address worth reloading.
    it 'sends the user to the tracking of the exchange the contract opened' do
      post admin_demo_confirmation_path

      expect(response).to redirect_to(admin_demo_suivi_path)
    end

    describe 'the conversation of chapter 4.4 §4.3.2' do
      # CA6, first half: « SHOULD be reused for combined flows ».
      it 'reuses the conversation of the first request for the second' do
        post admin_demo_confirmation_path
        post admin_demo_confirmation_path

        expect(evidence_request_query['idConversation']).to eq(accepted_body.fetch(:conversation))
      end

      it 'names no conversation on the first request, having none to name' do
        post admin_demo_confirmation_path

        expect(evidence_request_query).not_to have_key('idConversation')
      end

      # CA6, second half: « MUST NOT be reused if the user authenticates with a
      # different identity. » The pseudonym FranceConnect+ hands this service
      # provider is what tells one identity from another.
      it 'starts a new conversation when another identity signs in' do
        post admin_demo_confirmation_path

        # Both halves, because `Demo::CompleteIdentification` refuses an ID
        # Token and a UserInfo response naming two different people.
        autre = "#{'b' * 64}v1"
        identify_demo_user(userinfo: FranceConnectStubs::DANISH_USERINFO.merge('sub' => autre), sub: autre)
        post admin_demo_confirmation_path

        expect(evidence_request_query).not_to have_key('idConversation')
      end
    end

    # Requirement 27 of chapter 1 §2 wants the provider and the evidence type
    # named « before any request is made », so what the page showed is filed
    # with the request that left. The procedure's own title is filed beside
    # them and is not one of the two: neither the code list nor the directory
    # names `T1` here, and the press is offered all the same.
    it 'files what requirement 27 had the page name' do
      post admin_demo_confirmation_path

      expect(Demo::Request.last).to have_attributes(
        evidence_type_name: 'Dummy PDF - FI', provider_name: 'Keha v. 2.0', procedure_name: nil,
      )
    end

    # CA9. Three refusals pronounced before any exchange exists, told apart by
    # the status alone, which is all a service provider's server has to go on.
    describe 'a refusal that opens nothing' do
      it 'says what the contract refused, with the message it returned' do
        stub_evidence_request(status: 422, body: { erreur: 'EB:ERR:0001 : requête invalide' }.to_json)

        post admin_demo_confirmation_path

        expect(response.parsed_body.css('main').text)
          .to include('refusée', 'EB:ERR:0001', 'No exchange was opened')
      end

      it 'says the service could not be reached on a 502' do
        stub_evidence_request(status: 502, body: { erreur: 'Annuaire injoignable' }.to_json)

        post admin_demo_confirmation_path

        expect(response.parsed_body.css('main').text).to include("n'a pas pu être joint")
      end

      # The feature switch answers in plain text and not in JSON: the client has
      # to bear that without raising.
      it 'says the querying is locked on a 501' do
        stub_evidence_request(status: 501, body: 'Not Implemented Yet!')

        post admin_demo_confirmation_path

        expect(response.parsed_body.css('main').text).to include('verrouillé')
      end

      it 'names the status of anything else, having no sentence for it' do
        stub_evidence_request(status: 500, body: { erreur: 'Configuration' }.to_json)

        post admin_demo_confirmation_path

        expect(response.parsed_body.css('main').text).to include('500')
      end

      # Le seul état qu'un refus pourrait laisser derrière lui dans ce process :
      # la conversation en session. Éprouvé sur les quatre statuts, parce que
      # c'est `refuse` et non `keep` qui doit être pris à chaque fois — et
      # qu'une table de correspondance se trompe sur une entrée à la fois.
      [
        [422, { erreur: 'EB:ERR:0001' }.to_json],
        [501, 'Not Implemented Yet!'],
        [502, { erreur: 'Annuaire injoignable' }.to_json],
        [500, { erreur: 'Configuration' }.to_json],
      ].each do |status, body|
        it "holds no conversation to reuse after a #{status}" do
          stub_evidence_request(status:, body:)
          post admin_demo_confirmation_path

          stub_evidence_request
          post admin_demo_confirmation_path

          expect(evidence_request_query).not_to have_key('idConversation')
        end
      end

      # `EvidenceRequestsController` bâtit son `202` sur un `Exchange`, donc il
      # nomme toujours l'échange : un `202` qui n'en nomme aucun est un corps
      # qui n'est pas arrivé entier, et le montrer comme un succès afficherait
      # une requête partie dont rien ne dit laquelle.
      # Éprouvé sur la vraie route et non sur un double du client : ce qui est en
      # question est que le client laisse bien échapper la panne, pas que
      # l'interacteur sache la traiter.
      it 'says the service could not be reached when nothing answers at all' do
        stub_request(:get, "#{Settings.oots_france_url}/requete/pieceJustificative")
          .with(query: hash_including({})).to_timeout

        post admin_demo_confirmation_path

        expect(response.parsed_body.css('main').text).to include("n'a pas pu être joint")
      end

      # Le jeu de clés est lu en HTTP avant que la requête parte : une page de
      # maintenance rendue en `200` n'est pas une panne réseau, et n'échappait
      # à aucun rattrapage avant qu'on la nomme.
      it 'says the same when the key set answers something no key can be read from' do
        stub_request(:get, "#{Settings.oots_france_url}/auth/cles_publiques")
          .to_return(body: '<html>maintenance</html>', headers: { 'Content-Type' => 'text/html' })

        post admin_demo_confirmation_path

        expect(response.parsed_body.css('main').text).to include("n'a pas pu être joint")
      end

      it 'refuses an acceptance that names no exchange' do
        stub_evidence_request(status: 202, body: 'une réponse tronquée')

        post admin_demo_confirmation_path

        expect(response.parsed_body.css('main').text).to include('inattendue', '202')
        expect(response.parsed_body.css('main').text).not_to include('La demande est partie')
      end
    end
  end

  # The same requirement 27, seen from the page that did open but could name
  # nothing: the session then holds a record with blank names, which is not the
  # same shape as no record at all.
  describe 'POST /admin/demo/confirmation, the page having named nothing' do
    before do
      stub_oots_france_public_keys
      stub_evidence_request
      stub_directory('dsd', 'dataservices-by-evidencetype', 'dsd_aucun_service_fr')
      get admin_demo_confirmation_path
    end

    it 'asks the contract nothing, and sends the user back' do
      post admin_demo_confirmation_path

      expect(a_request(:get, "#{Settings.oots_france_url}/requete/pieceJustificative")
        .with(query: hash_including({}))).not_to have_been_made
      expect(response).to redirect_to(admin_demo_confirmation_path)
    end
  end

  # The same requirement 27, the other way round, and the one case the describe
  # above cannot hold: nothing here opens the page first, so the press has been
  # shown neither name.
  describe 'POST /admin/demo/confirmation, without the page having named anything' do
    before do
      stub_oots_france_public_keys
      stub_evidence_request
    end

    it 'asks the contract nothing' do
      post admin_demo_confirmation_path

      expect(a_request(:get, "#{Settings.oots_france_url}/requete/pieceJustificative")
        .with(query: hash_including({}))).not_to have_been_made
    end

    it 'sends the user back to the page that names what would be asked' do
      post admin_demo_confirmation_path

      expect(response).to redirect_to(admin_demo_confirmation_path)
    end
  end

  # The session is the operator's, and `Demo::UserIdentity.from_session` answers
  # `nil` to anything it can no longer read.
  def reset_session_identity
    allow(Demo::UserIdentity).to receive(:from_session).and_return(nil)
  end
end
