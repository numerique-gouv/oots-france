require 'rails_helper'

RSpec.describe 'Admin::Demo::Documents' do
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
      get admin_demo_documents_path

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.css('main').text).to include('Keha v. 2.0', 'Dummy PDF - FI')
    end

    # A portal's own sentences and the words Brussels publishes read alike on a
    # screen: these two are the directories', and the page says so.
    it 'marks those two as published by the directories, and the identity not' do
      get admin_demo_documents_path

      marked = response.parsed_body.css('main .directory-value').map { |value| seen(value) }

      expect(marked).to contain_exactly('(TEST) Test Requirement', 'Dummy PDF - FI', 'Keha v. 2.0')
    end

    it 'asks the contract nothing: nothing is opened by looking at the page' do
      get admin_demo_documents_path

      expect(a_request(:get, "#{Settings.oots_france_url}/requete/pieceJustificative")
        .with(query: hash_including({}))).not_to have_been_made
    end

    # The resolution walks the chain a request walks: the procedure is asked at
    # home, the evidence types in the country the evidence is sought in — both
    # `FR` here, the demonstration making France talk to France.
    it 'asks about the study financing procedure in France' do
      get admin_demo_documents_path

      expect(a_request(:get, "#{DirectoryStubs::ACCEPTANCE}/eb/rest/search")
        .with(query: hash_including('procedure-id' => 'T1', 'country-code' => 'FR'))).to have_been_made
    end

    # Chapter 2.2 §2 makes the portal answerable for the identity in the request
    # matching the one the eID means yielded, so the page shows it and offers no
    # field on it.
    it 'shows the identity the authentication attested, and offers no field on it' do
      get admin_demo_documents_path

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
      get admin_demo_documents_path

      expect(response.body).not_to include(FranceConnectStubs::DANISH_USERINFO.fetch('sub'))
    end

    # Unable to name the two, it must not offer to confirm: requirement 27 makes
    # them a condition of the request, not a decoration on it. The card stays
    # all the same — a requirement no country serves is still one the procedure
    # rests on — and it is the footer that says so, in the portal's own words:
    # the code the directory returned belongs to the console, not here.
    it 'keeps the card and says in its footer that nothing is published' do
      stub_directory('dsd', 'dataservices-by-evidencetype', 'dsd_aucun_service_fr')

      get admin_demo_documents_path

      carte = response.parsed_body.at_css('main .requirement-card')

      expect(seen(carte.at_css('h3'))).to eq('(TEST) Test Requirement')
      expect(carte.at_css('.fr-card__desc').text.squish).to eq('Evidence impossible to satisfy by 🇫🇷 France (FR)')
      expect(carte.at_css('.requirement-card__actions').text.squish)
        .to eq('⚠️No provider listed by France for this evidence')
      expect(carte.at_css('.fr-card__desc .country-tag')).to be_present
      expect(carte.classes).to include('requirement-card--unsatisfiable')
      expect(response.parsed_body.css("form[action='#{admin_demo_demande_path}']")).to be_empty
    end

    # A directory that refuses carries a code and raises nothing: the page keeps
    # its section and says what is known — nothing was listed — rather than
    # standing under a heading followed by nothing.
    it 'says that nothing was listed when the Evidence Broker refuses' do
      stub_directory('eb', 'requirements-by-procedure', 'eb_requirements_vides')

      get admin_demo_documents_path

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

      get admin_demo_documents_path

      expect(response.parsed_body.at_css('main .requirement-card__actions').text.squish)
        .to eq('⚠️France could not answer for this evidence')
    end

    # One card per requirement the procedure rests on, each naming its own
    # evidence type and provider.
    it 'offers a card per requirement the procedure rests on' do
      stub_directory('eb', 'requirements-by-procedure', 'eb_requirements_t1_fr')

      get admin_demo_documents_path

      titres = response.parsed_body.css('main .requirement-card h3').map { |titre| seen(titre) }

      expect(titres).to eq(['(TEST) Test Requirement 2', 'Proof of enrolment in academic tertiary education'])
    end

    # The jurisdiction the documents would come from, named on the card as the
    # directory pages name one: a requirement is satisfied somewhere, and
    # « somewhere » is a country.
    it 'names the country the documents would be requested in' do
      get admin_demo_documents_path

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

      get admin_demo_documents_path

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

      get admin_demo_documents_path

      cartes = response.parsed_body.css('main .requirement-card')

      expect(cartes.css('.demo-request__body').size).to eq(2)
      expect(cartes.css('button').map { |bouton| bouton.text.squish }).to eq(['Request the document'] * 2)
      expect(cartes.css('[data-controller="demo-request"]').pluck('data-demo-request-url-value'))
        .to eq([admin_demo_demande_path(exigence: premiere), admin_demo_demande_path(exigence: seconde)])
    end

    # CA8. Requirement 27 makes the two names a condition of the request, so a
    # requirement the country serves with nothing carries neither button nor
    # zone — and its neighbours keep theirs.
    it 'leaves a requirement the country does not serve without button or zone' do
      stub_directory('eb', 'requirements-by-procedure', 'eb_requirements_t1_fr')
      stub_directory('eb', 'evidence-types-by-requirement', 'eb_requirements_vides', requirement: seconde_id)

      get admin_demo_documents_path

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

      get admin_demo_documents_path

      expect(response).to have_http_status(:bad_gateway)
      expect(response.parsed_body.css('main').text).to include('could not be reached')
      expect(response.parsed_body.css("form[action='#{admin_demo_demande_path}']")).to be_empty
    end

    it 'sends an operator holding no identity back to the start' do
      reset_session_identity

      get admin_demo_documents_path

      expect(response).to redirect_to(admin_demo_root_path)
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
      get admin_demo_documents_path
      post demande_path
    end

    it 'opens on the waiting rather than on a button that would start a second' do
      get admin_demo_documents_path

      expect(response.parsed_body.at_css('.demo-request__body')['data-polling']).to eq('true')
      expect(response.parsed_body.css('main').text).to include('Requesting the document')
    end

    it 'opens on the document once it has been filed, and asks the contract nothing more' do
      Demo::Request.sole.receive_evidence!("%PDF-1.4\ndrapeau".b)

      get admin_demo_documents_path

      expect(response.parsed_body.css('main').text).to include('Document retrieved successfully')
      expect(a_request(:get, "#{Settings.oots_france_url}/requete/pieceJustificative")
        .with(query: hash_including({}))).to have_been_made.once
    end
  end

  # The session is the operator's, and `Demo::UserIdentity.from_session` answers
  # `nil` to anything it can no longer read.
  def reset_session_identity
    allow(Demo::UserIdentity).to receive(:from_session).and_return(nil)
  end

  def seconde_id = "https://sr.acc.oots.tech.ec.europa.eu/requirements/#{seconde}"

  def demande_path(uuid = exigence) = admin_demo_demande_path(exigence: uuid)
end
