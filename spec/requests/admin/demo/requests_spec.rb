require 'rails_helper'

RSpec.describe 'Admin::Demo::Requests' do
  # The one requirement `eb_requirements_fr` holds, which every press below is
  # about: a page carries one zone per requirement it can name, and the address
  # of each names its own.
  let(:exigence) { '00000000-0000-0000-0000-000000000000' }

  before do
    sign_in
    identify_demo_user
    stub_code_list
    stub_directory_resolution
    stub_directory('eb', 'requirements-by-procedure', 'eb_requirements_fr')
    stub_directory('eb', 'evidence-types-by-requirement', 'eb_evidence_types_fi')
    stub_directory('dsd', 'dataservices-by-evidencetype', 'dsd_data_services_fi')
  end

  describe 'POST /admin/demo/demande' do
    before do
      stub_oots_france_public_keys
      stub_evidence_request
      # The press answers with the zone, which says where the request stands:
      # the state of the exchange it just opened is read back through the same
      # contract, as a service provider's server would read it.
      stub_exchange_state
      # The page requirement 27 is satisfied on: a press only exists once it has
      # been shown what it would ask for.
      get admin_demo_documents_path
    end

    # CA3: the request goes out through the contract, with the query string a
    # French service provider's server would send.
    it 'asks for the evidence through GET /requete/pieceJustificative' do
      post demande_path

      expect(evidence_request_query).to include(
        'codeDemarche' => 'T1', 'codePays' => 'FR',
        'previsualisationRequise' => 'false', 'idRequeteur' => '00000000000003',
      )
    end

    it 'sends a beneficiary token and never the pseudonym FranceConnect+ handed it' do
      post demande_path

      expect(evidence_request_query['beneficiaire']).to be_present
      expect(evidence_request_query['beneficiaire']).not_to include(FranceConnectStubs::DANISH_USERINFO.fetch('sub'))
    end

    # A request that left comes back as the zone it was pressed in, waiting: the
    # answer arrives on another connection, and this is the element that will
    # keep asking for it.
    it 'answers the zone of the press, waiting on the exchange the contract opened' do
      post demande_path

      expect(response.headers['Deferred-Fragment']).to eq('1')
      expect(response.parsed_body.at_css('.demo-request__body')['data-polling']).to eq('true')
      expect(response.parsed_body.text).to include('Requesting the document')
    end

    # A fragment and not a page: spliced back into the card, a layout would land
    # a second banner, menu and footer inside it.
    it 'answers the zone alone, with nothing of the layout around it' do
      post demande_path

      expect(response.parsed_body.css('header, footer, nav')).to be_empty
    end

    describe 'the conversation of chapter 4.4 §4.3.2' do
      # CA6, first half: « SHOULD be reused for combined flows ».
      it 'reuses the conversation of the first request for the second' do
        post demande_path
        post demande_path

        expect(evidence_request_query['idConversation']).to eq(accepted_body.fetch(:conversation))
      end

      it 'names no conversation on the first request, having none to name' do
        post demande_path

        expect(evidence_request_query).not_to have_key('idConversation')
      end

      # CA6, second half: « MUST NOT be reused if the user authenticates with a
      # different identity. » The pseudonym FranceConnect+ hands this service
      # provider is what tells one identity from another.
      it 'starts a new conversation when another identity signs in' do
        post demande_path

        # Both halves, because `Demo::CompleteIdentification` refuses an ID
        # Token and a UserInfo response naming two different people.
        autre = "#{'b' * 64}v1"
        identify_demo_user(userinfo: FranceConnectStubs::DANISH_USERINFO.merge('sub' => autre), sub: autre)
        post demande_path

        expect(evidence_request_query).not_to have_key('idConversation')
      end
    end

    # Requirement 27 of chapter 1 §2 wants the provider and the evidence type
    # named « before any request is made », so what the page showed is filed
    # with the request that left. The procedure's own title is filed beside
    # them and is not one of the two: neither the code list nor the directory
    # names `T1` here, and the press is offered all the same.
    #
    # The requirement joins them: a procedure rests on several, each asked for
    # by its own press, and a row naming the document without the obligation it
    # was asked under would not say which press it answers.
    it 'files what requirement 27 had the page name, and the requirement it named it under' do
      post demande_path

      expect(Demo::Request.last).to have_attributes(
        evidence_type_name: 'Dummy PDF - FI', provider_name: 'Keha v. 2.0', procedure_name: nil,
        requirement_id: "https://sr.acc.oots.tech.ec.europa.eu/requirements/#{exigence}",
        requirement_name: '(TEST) Test Requirement', requirement_language: 'EN',
      )
    end

    # The whole point of `idExigence`: the press of one card asks for that
    # card's requirement, and the contract is told which.
    it 'names the requirement of the card it was pressed in' do
      post demande_path

      expect(evidence_request_query['idExigence'])
        .to eq("https://sr.acc.oots.tech.ec.europa.eu/requirements/#{exigence}")
    end

    # CA9. Three refusals pronounced before any exchange exists, told apart by
    # the status alone, which is all a service provider's server has to go on.
    describe 'a refusal that opens nothing' do
      it 'says what the contract refused, with the message it returned' do
        stub_evidence_request(status: 422, body: { erreur: 'EB:ERR:0001 : requête invalide' }.to_json)

        post demande_path

        expect(response.parsed_body.text).to include('refusée', 'EB:ERR:0001')
      end

      it 'says the service could not be reached on a 502' do
        stub_evidence_request(status: 502, body: { erreur: 'Annuaire injoignable' }.to_json)

        post demande_path

        expect(response.parsed_body.text).to include("n'a pas pu être joint")
      end

      # The feature switch answers in plain text and not in JSON: the client has
      # to bear that without raising.
      it 'says the querying is locked on a 501' do
        stub_evidence_request(status: 501, body: 'Not Implemented Yet!')

        post demande_path

        expect(response.parsed_body.text).to include('verrouillé')
      end

      it 'names the status of anything else, having no sentence for it' do
        stub_evidence_request(status: 500, body: { erreur: 'Configuration' }.to_json)

        post demande_path

        expect(response.parsed_body.text).to include('500')
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
          post demande_path

          stub_evidence_request
          post demande_path

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

        post demande_path

        expect(response.parsed_body.text).to include("n'a pas pu être joint")
      end

      # Le jeu de clés est lu en HTTP avant que la requête parte : une page de
      # maintenance rendue en `200` n'est pas une panne réseau, et n'échappait
      # à aucun rattrapage avant qu'on la nomme.
      it 'says the same when the key set answers something no key can be read from' do
        stub_request(:get, "#{Settings.oots_france_url}/auth/cles_publiques")
          .to_return(body: '<html>maintenance</html>', headers: { 'Content-Type' => 'text/html' })

        post demande_path

        expect(response.parsed_body.text).to include("n'a pas pu être joint")
      end

      it 'refuses an acceptance that names no exchange' do
        stub_evidence_request(status: 202, body: 'une réponse tronquée')

        post demande_path

        expect(response.parsed_body.text).to include('inattendue', '202')
      end

      # A refusal opened no exchange, so there is nothing to wait on: the zone
      # offers the press again rather than asking after an answer nobody is
      # going to send.
      it 'offers the press again rather than waiting on nothing' do
        stub_evidence_request(status: 422, body: { erreur: 'EB:ERR:0001' }.to_json)

        post demande_path

        expect(response.parsed_body.at_css('.demo-request__body')['data-polling']).to eq('false')
        expect(response.parsed_body.text).to include('Retry to request')
      end
    end
  end

  # The same requirement 27, seen from the page that did open but could name
  # nothing: the session then holds a record with blank names, which is not the
  # same shape as no record at all.
  describe 'POST /admin/demo/demande, the page having named nothing' do
    before do
      stub_oots_france_public_keys
      stub_evidence_request
      stub_directory('dsd', 'dataservices-by-evidencetype', 'dsd_aucun_service_fr')
      get admin_demo_documents_path
    end

    it 'asks the contract nothing, and sends the user back' do
      post demande_path

      expect(a_request(:get, "#{Settings.oots_france_url}/requete/pieceJustificative")
        .with(query: hash_including({}))).not_to have_been_made
      expect(response).to redirect_to(admin_demo_documents_path)
    end
  end

  # The parameter comes from the client, and the card that would carry it is
  # the only thing that keeps it honest on screen. Requirement 27 of chapter 1
  # §2 makes the two names a condition of the request, so a press naming a
  # requirement the page never named has been shown nothing to confirm — and
  # `named` reads them under that requirement alone, which is what makes this
  # guard load-bearing rather than decorative.
  describe 'POST /admin/demo/demande, naming a requirement the page never offered' do
    before do
      stub_oots_france_public_keys
      stub_evidence_request
      stub_exchange_state
      get admin_demo_documents_path
    end

    # Never the first requirement that publishes: falling back would ask for a
    # document under a name nobody confirmed.
    it 'asks the contract nothing for a requirement the session has not named' do
      post demande_path('11111111-2222-3333-4444-555555555555')

      expect(a_request(:get, "#{Settings.oots_france_url}/requete/pieceJustificative")
        .with(query: hash_including({}))).not_to have_been_made
      expect(response).to redirect_to(admin_demo_documents_path)
      expect(Demo::Request.count).to eq(0)
    end

    it 'asks the contract nothing when no requirement is named at all' do
      post admin_demo_demande_path

      expect(a_request(:get, "#{Settings.oots_france_url}/requete/pieceJustificative")
        .with(query: hash_including({}))).not_to have_been_made
      expect(response).to redirect_to(admin_demo_documents_path)
      expect(Demo::Request.count).to eq(0)
    end
  end

  # The same requirement 27, the other way round, and the one case the describe
  # above cannot hold: nothing here opens the page first, so the press has been
  # shown neither name.
  describe 'POST /admin/demo/demande, without the page having named anything' do
    before do
      stub_oots_france_public_keys
      stub_evidence_request
    end

    it 'asks the contract nothing' do
      post demande_path

      expect(a_request(:get, "#{Settings.oots_france_url}/requete/pieceJustificative")
        .with(query: hash_including({}))).not_to have_been_made
    end

    it 'sends the user back to the page that names what would be asked' do
      post demande_path

      expect(response).to redirect_to(admin_demo_documents_path)
    end
  end

  # Identifying starts a journey, and the demonstration is walked over and over:
  # the exchange the session followed belonged to the journey before, and a zone
  # still offering its document would leave the operator nothing to press.
  describe 'walking the journey a second time' do
    before do
      stub_oots_france_public_keys
      stub_evidence_request
      stub_exchange_state
      get admin_demo_documents_path
      post demande_path
      Demo::Request.sole.receive_evidence!("%PDF-1.4\ndrapeau".b)
    end

    it 'offers the press again once the user has identified anew' do
      identify_demo_user
      get admin_demo_documents_path

      expect(response.parsed_body.at_css('.demo-request__body').text).to include('Request the document')
      expect(response.parsed_body.at_css('.demo-request__body')['data-outcome']).to eq('idle')
      expect(response.parsed_body.css('.demo-request__body a[target="_blank"]')).to be_empty
    end

    # Chapter 4.4 §4.1: « a new unique request MUST be issued » — a second
    # journey is a second exchange, and the register carries both.
    it 'opens a second exchange rather than following the first' do
      identify_demo_user
      stub_evidence_request(body: { echange: 'un-second-echange',
                                    conversation: DemoContractStubs::ACCEPTED_CONVERSATION,
                                    statut: 'pending' }.to_json)
      stub_exchange_state('un-second-echange', statut: 'pending')

      get admin_demo_documents_path
      post demande_path

      expect(Demo::Request.pluck(:exchange_id))
        .to contain_exactly(DemoContractStubs::ACCEPTED_EXCHANGE, 'un-second-echange')
    end

    # Chapter 4.4 §4.3.2: the conversation « SHOULD be reused for combined
    # flows », and only « a different identity » forbids it — walking the
    # journey again under the same identity is not one.
    it 'keeps the conversation of the journey before' do
      identify_demo_user
      stub_exchange_state('un-second-echange', statut: 'pending')

      get admin_demo_documents_path
      post demande_path

      expect(evidence_request_query['idConversation']).to eq(accepted_body.fetch(:conversation))
    end
  end

  # L'adresse que la zone redemande toutes les deux secondes tant qu'elle attend.
  # Éprouvée par une vraie requête HTTP, à travers la session et le contrat : un
  # oubli de l'en-tête ou du fragment casserait toute la scrutation sans faire
  # échouer une seule des specs de composant, qui construisent leurs objets à la
  # main.
  describe 'GET /admin/demo/demande' do
    before do
      stub_oots_france_public_keys
      stub_evidence_request
      stub_exchange_state
      get admin_demo_documents_path
      post demande_path
    end

    it 'answers the zone as a fragment this application wrote, and nothing of the layout' do
      get demande_path

      expect(response).to have_http_status(:ok)
      expect(response.headers['Deferred-Fragment']).to eq('1')
      expect(response.parsed_body.css('header, footer, nav')).to be_empty
    end

    # Le contrat dit que l'échange est en cours et rien n'a été remis : la zone
    # attend, et le dit au contrôleur Stimulus par `data-polling`.
    it 'reads the waiting back from the contract, and declares itself waiting' do
      get demande_path

      expect(response.parsed_body.at_css('.demo-request__body')['data-polling']).to eq('true')
      expect(response.parsed_body.text).to include('Requesting the document')
    end

    # Le document remis par le worker règle l'état, quoi que dise le contrat.
    it 'offers the document once it has been filed against the exchange' do
      Demo::Request.sole.receive_evidence!("%PDF-1.4\ndrapeau".b)

      get demande_path

      expect(response.parsed_body.at_css('.demo-request__body')['data-outcome']).to eq('delivered')
      expect(response.parsed_body.text).to include('Document retrieved successfully')
    end

    # Chapitre 2.1 §3.3 : le refus du correspondant est dit à l'usager, avec le
    # code qui nomme lequel.
    it 'says the correspondent refused, with the code it returned' do
      stub_exchange_state(statut: 'failed', codeErreur: 'EDM:ERR:0003')

      get demande_path

      expect(response.parsed_body.at_css('.demo-request__body')['data-outcome']).to eq('failed')
      expect(response.parsed_body.text).to include('EDM:ERR:0003', 'Retry to request')
    end

    # Le contrat injoignable ne dit rien de l'échange : la zone rapporte la panne
    # là où elle rapporterait un refus, et cesse d'attendre.
    it 'reports an unreachable contract rather than presenting it as an answer' do
      stub_request(:get, %r{/requete/}).to_timeout

      get demande_path

      expect(response.parsed_body.at_css('.demo-request__body')['data-polling']).to eq('false')
      expect(response.parsed_body.text).to include('could not be read')
    end

    it 'sends an operator holding no identity back to the start' do
      allow(Demo::UserIdentity).to receive(:from_session).and_return(nil)

      get demande_path

      expect(response).to redirect_to(admin_demo_root_path)
    end
  end

  # Chapter 4.4 §4.2.2: « When the execution of a procedure for a user requires
  # multiple pieces of evidence, possibly of different types and possibly from
  # different Data Services, different basic flows may be executed sequentially
  # and/or in parallel. » The demonstration procedure rests on two requirements,
  # each with its own card, its own zone and its own request — and the doubled
  # directories serve both, where acceptance serves one this day.
  describe 'two requirements asked for at once' do
    let(:premiere) { 'ffffffff-ffff-ffff-ffff-ffffffffffff' }
    let(:seconde) { '2d21a531-d30e-4e30-9e5e-b53d6aedb30b' }
    let(:second_echange) { 'aaaaaaaa-0000-4000-8000-000000000002' }

    before do
      stub_directory('eb', 'requirements-by-procedure', 'eb_requirements_t1_fr')
      stub_oots_france_public_keys
      stub_evidence_request
      stub_evidence_request_for(seconde, second_echange)
      stub_exchange_state
      stub_exchange_state(second_echange, statut: 'pending')
      get admin_demo_documents_path
    end

    # CA6. Chapter 4.4 §4.3.2 gives each identifier its own job: the
    # conversation « MAY span multiple actions, procedures, and evidence
    # exchanges within one user session », where the `ExchangeId` « Identifies
    # one evidence exchange ».
    it 'opens two exchanges under one conversation, neither waiting on the other' do
      post demande_path(premiere)
      post demande_path(seconde)

      expect(Demo::Request.pluck(:exchange_id))
        .to contain_exactly(DemoContractStubs::ACCEPTED_EXCHANGE, second_echange)
      expect(Demo::Request.distinct.pluck(:conversation_id)).to eq([DemoContractStubs::ACCEPTED_CONVERSATION])
      expect(contract_demands.size).to eq(2)
    end

    # CA7. Requirement 27 has the evidence type and the provider named « before
    # any request is made », so a press files what its own card named — the
    # requirement being the one name that tells the two cards apart here, the
    # doubled directories answering both alike.
    it 'files the requirement of the card pressed, and not that of its neighbour' do
      post demande_path(premiere)
      post demande_path(seconde)

      expect(Demo::Request.find_by(exchange_id: second_echange)).to have_attributes(
        requirement_id: requirement_uri(seconde),
        requirement_name: 'Proof of enrolment in academic tertiary education',
        requirement_language: 'EN', evidence_type_name: 'Dummy PDF - FI', provider_name: 'Keha v. 2.0',
      )
      expect(Demo::Request.find_by(exchange_id: DemoContractStubs::ACCEPTED_EXCHANGE).requirement_id)
        .to eq(requirement_uri(premiere))
    end

    it 'names its own requirement to the contract on each press' do
      post demande_path(premiere)
      post demande_path(seconde)

      expect(contract_demands.map { |demand| Rack::Utils.parse_nested_query(demand.uri.query)['idExigence'] })
        .to eq([requirement_uri(premiere), requirement_uri(seconde)])
    end

    # CA10. One zone settling says nothing of the others: each reports on the
    # request it follows and on no other.
    it 'settles one zone while the other is still waiting' do
      post demande_path(premiere)
      post demande_path(seconde)
      Demo::Request.find_by(exchange_id: DemoContractStubs::ACCEPTED_EXCHANGE).receive_evidence!(document)

      get admin_demo_documents_path

      zones = response.parsed_body.css('main .demo-request__body')

      expect(zones.first.text).to include('Document retrieved successfully', 'Open the document')
      expect(zones.last.text).to include('Requesting the document')
      expect(zones.last.text).not_to include('Document retrieved successfully')
    end

    # CA11. A refusal is the correspondent's answer to one exchange, and the
    # zone of the other has nothing to say about it.
    it 'reports a refusal on the zone it answers, leaving the other untouched' do
      post demande_path(premiere)
      post demande_path(seconde)
      stub_exchange_state(statut: 'failed', codeErreur: 'EDM:ERR:0003')

      get admin_demo_documents_path

      zones = response.parsed_body.css('main .demo-request__body')

      expect(zones.first.text).to include('EDM:ERR:0003', 'Retry to request')
      expect(zones.last['data-outcome']).to eq('pending')
      expect(zones.last.text).not_to include('EDM:ERR:0003')
    end

    # CA12, first half. Chapter 1 §4.2: the evidence is « made available to the
    # specific procedure end-user that issued the query for those evidences »,
    # and the requirement says which of that user's queries is meant.
    it 'serves the document of the request the address names' do
      post demande_path(premiere)
      post demande_path(seconde)
      Demo::Request.find_by(exchange_id: DemoContractStubs::ACCEPTED_EXCHANGE).receive_evidence!(document)
      Demo::Request.find_by(exchange_id: second_echange).receive_evidence!(autre_document)

      get admin_demo_justificatif_path(exigence: seconde)

      expect(response.body.b).to eq(autre_document)
    end

    # CA12, second half. Another session followed neither request, so neither
    # the document nor the zone of one is anything it may obtain.
    it 'serves neither document nor zone to a session that followed neither request' do
      post demande_path(premiere)
      Demo::Request.find_by(exchange_id: DemoContractStubs::ACCEPTED_EXCHANGE).receive_evidence!(document)

      identify_demo_user

      get admin_demo_justificatif_path(exigence: premiere)
      expect(response).to redirect_to(admin_demo_documents_path)

      get demande_path(premiere)
      expect(response.parsed_body.at_css('.demo-request__body')['data-outcome']).to eq('idle')
    end

    # CA13. A requirement has one request under way at a time — the zone simply
    # does not offer the press — and asking again after a refusal is « a new
    # unique request » (chapter 4.4 §4.1), with an `ExchangeId` of its own.
    it 'hides the press while its own request runs, and opens a new exchange on the retry' do
      post demande_path(premiere)

      expect(response.parsed_body.at_css('.demo-request__press')).to be_present
      expect(response.parsed_body.at_css('.demo-request__press')['hidden']).to be_truthy

      stub_exchange_state(statut: 'failed', codeErreur: 'EDM:ERR:0003')
      stub_evidence_request_for(premiere, 'aaaaaaaa-0000-4000-8000-000000000003')
      stub_exchange_state('aaaaaaaa-0000-4000-8000-000000000003', statut: 'pending')

      post demande_path(premiere)

      expect(response.parsed_body.at_css('.demo-request__body')['data-polling']).to eq('true')
      expect(evidence_request_query['idConversation']).to eq(DemoContractStubs::ACCEPTED_CONVERSATION)
      expect(Demo::Request.pluck(:exchange_id))
        .to contain_exactly(DemoContractStubs::ACCEPTED_EXCHANGE, 'aaaaaaaa-0000-4000-8000-000000000003')
    end

    # CA14. Chapter 4.4 §4.1 makes a further reference cost « a new unique
    # request », from which this repository infers that re-reading costs
    # nothing: a reload renders each zone where the server says its own request
    # stands, and opens nothing.
    it 'reloads each zone on its own request, asking the contract for nothing more' do
      post demande_path(premiere)
      post demande_path(seconde)
      Demo::Request.find_by(exchange_id: DemoContractStubs::ACCEPTED_EXCHANGE).receive_evidence!(document)

      get admin_demo_documents_path

      zones = response.parsed_body.css('main .demo-request__body')

      expect(zones.pluck('data-outcome')).to eq(%w[delivered pending])
      expect(contract_demands.size).to eq(2)
    end

    # CA15. Identifying starts a journey, and the requests the session followed
    # belonged to the one before. The conversation survives an identity that has
    # not changed — chapter 4.4 §4.3.2 forbids reuse only « if the user
    # authenticates with a different identity ».
    it 'drops every request it followed when the user identifies anew, keeping the conversation' do
      post demande_path(premiere)
      post demande_path(seconde)

      identify_demo_user
      get admin_demo_documents_path

      zones = response.parsed_body.css('main .demo-request__body')

      expect(zones.pluck('data-outcome')).to eq(%w[idle idle])
      expect(zones.map(&:text).join).to include('Request the document')

      stub_evidence_request_for(premiere, 'aaaaaaaa-0000-4000-8000-000000000004')
      stub_exchange_state('aaaaaaaa-0000-4000-8000-000000000004', statut: 'pending')
      post demande_path(premiere)

      expect(evidence_request_query['idConversation']).to eq(DemoContractStubs::ACCEPTED_CONVERSATION)
    end

    def document = "%PDF-1.4\npremier".b

    def autre_document = "%PDF-1.4\nsecond".b

    def requirement_uri(uuid) = "https://sr.acc.oots.tech.ec.europa.eu/requirements/#{uuid}"

    # Registered after the general one, so that WebMock prefers it: the contract
    # answers a different exchange to each requirement, which is what makes two
    # presses two exchanges rather than one read twice.
    def stub_evidence_request_for(uuid, exchange_id)
      stub_request(:get, "#{Settings.oots_france_url}#{DemoContractStubs::PATH}")
        .with(query: hash_including('idExigence' => requirement_uri(uuid)))
        .to_return(status: 202, headers: { 'Content-Type' => 'application/json' },
          body: { echange: exchange_id, conversation: DemoContractStubs::ACCEPTED_CONVERSATION,
                  statut: 'pending' }.to_json)
    end
  end

  def demande_path(uuid = exigence) = admin_demo_demande_path(exigence: uuid)
end
