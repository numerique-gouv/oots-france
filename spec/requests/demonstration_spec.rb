require 'rails_helper'

# The public entrance of the demonstration procedure, under `/demonstration`:
# the console's walk, screen for screen, played by a visitor holding no session
# of the console. What the console's own specs prove of each screen holds here
# by inheritance; these prove what the entrance changes.
RSpec.describe 'The public demonstration' do
  def page = response.parsed_body

  let(:exigence) { '00000000-0000-0000-0000-000000000000' }

  def public_entrance = Demo::Entrance::PUBLIC

  def identify_visitor(**) = identify_demo_user(entrance: public_entrance, **)

  def journey(entrance) = Demo::Journey.from_session(request.session[entrance.journey_key])

  def header_links = page.css('header .fr-nav__link, header .fr-header__tools-links a').map { seen(it) }

  def stub_documents_page
    stub_code_list
    stub_directory_resolution
    stub_directory('eb', 'requirements-by-procedure', 'eb_requirements_fr')
    stub_directory('eb', 'evidence-types-by-requirement', 'eb_evidence_types_fi')
    stub_directory('dsd', 'dataservices-by-evidencetype', 'dsd_data_services_fi')
  end

  before { declare_france_connect(fake_france_connect) }

  describe 'without a session of the console' do
    it 'shows the screen the line is chosen on, then the procedures, then the sign-in page' do
      stub_code_list
      stub_demonstration_requirements

      get '/demonstration'
      expect(response).to have_http_status(:ok)
      expect(page.css('.fr-card__title a').pluck('href')).to include('/demonstration/v2.0', '/demonstration/v1.2')

      get demonstration_procedures_path(version: 'v2.0')
      expect(response).to have_http_status(:ok)
      expect(page.css('.fr-card__title a').pluck('href')).to include('/demonstration/v2.0/T1')

      get demonstration_home_path(version: 'v2.0', procedure: 'T1')
      expect(response).to have_http_status(:ok)
    end

    it 'sends a page past the sign-in back to the screen the line is chosen on, never to the login of the console' do
      get demonstration_documents_path(version: 'v2.0', procedure: 'T1')

      expect(response).to redirect_to('/demonstration')
    end
  end

  describe 'what every screen carries' do
    before { get '/demonstration' }

    it 'carries the banner of a demonstration under the header' do
      expect(seen(page.at_css('.fr-notice--info .fr-notice__title'))).to eq('Démonstration — données fictives')
    end

    it 'carries the menu of the public site, and none of the links of the console' do
      expect(header_links).to include('OOTS en bref', 'Démo', 'Administration')
      expect(header_links).not_to include('Annuaires', 'Journal', 'Jobs', 'Se déconnecter')
    end

    it 'climbs to the front page of the site, not to the console' do
      expect(page.css('.fr-breadcrumb a').pluck('href').compact).to eq(['/'])
      expect(page.css('.fr-breadcrumb').text).not_to include('Administration')
    end

    it 'says the banner in English to a reader who chose English' do
      get '/demonstration', params: { locale: 'en' }
      follow_redirect! if response.redirect?

      expect(seen(page.at_css('.fr-notice--info .fr-notice__title'))).to eq('Demonstration — fictitious data')
    end
  end

  it 'leaves the screens of the console without the banner' do
    sign_in
    get '/admin/demo'

    expect(page.at_css('.fr-notice--info')).to be_nil
  end

  describe 'the way in from the public site' do
    it 'is a link of the menu on the front page and on the page of available evidence' do
      stub_code_list

      ['/', '/justificatifs_disponibles'].each do |path|
        get path

        expect(page.css('header .fr-nav__link').to_h { [seen(it), it['href']] }).to include('Démo' => '/demonstration')
      end
    end

    it 'exists where the real FranceConnect+ alone is declared' do
      stub_code_list
      undeclare_france_connect('fake')
      declare_france_connect(real_france_connect)

      get '/'
      expect(header_links).to include('Démo')

      get '/demonstration'
      expect(response).to have_http_status(:ok)
    end

    it 'does not exist where no FranceConnect+ is declared' do
      undeclare_france_connect('fake')

      get '/'
      expect(header_links).not_to include('Démo')

      get '/demonstration'
      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'the sign-in page, on a deployment declaring both FranceConnect+' do
    before do
      declare_france_connect(fake_france_connect, real_france_connect)
      stub_code_list
      stub_demonstration_requirements
    end

    def offered = page.css('input[name=france_connect]').pluck('value')

    it 'offers both on the public site, as on the console' do
      get demonstration_home_path(version: 'v2.0', procedure: 'T1')
      expect(offered).to eq(%w[real fake])

      sign_in
      get admin_demo_home_path(version: 'v2.0', procedure: 'T1')
      expect(offered).to eq(%w[real fake])
    end

    it 'departs to the real one from the public site, remembering the entrance' do
      stub_real_france_connect
      post demonstration_identification_path(version: 'v2.0', procedure: 'T1'), params: { france_connect: 'real' }

      expect(response.headers['Location']).to start_with(FranceConnectStubs::REAL_AUTHORIZATION_ENDPOINT)
      expect(session[:france_connect].symbolize_keys).to include(name: 'real', entrance: 'public')
    end
  end

  describe 'a visitor identified by the real FranceConnect+' do
    before { sign_in }

    it 'walks the public journey, apart from the console of the same browser' do
      identify_demo_user
      console_journey = journey(Demo::Entrance::CONSOLE)

      identify_visitor(userinfo: FranceConnectStubs::REQUESTED_USERINFO, instance: real_france_connect)

      expect(response).to redirect_to(demonstration_documents_path(version: 'v2.0', procedure: 'T1'))
      expect(held_demo_identity(public_entrance)).to include(family_name: 'Dupont', france_connect: 'real')
      expect(journey(public_entrance).id).not_to eq(console_journey.id)
      expect(journey(Demo::Entrance::CONSOLE).id).to eq(console_journey.id)
      expect(held_demo_identity[:family_name]).to eq('Sørensen')
    end

    it 'asks under the requester of the public site' do
      identify_visitor(instance: real_france_connect)
      stub_documents_page
      stub_oots_france_public_keys
      stub_evidence_request
      stub_exchange_state

      get demonstration_documents_path(version: 'v2.0', procedure: 'T1')
      post demonstration_demande_path(exigence:, type: named_type(exigence), version: 'v2.0', procedure: 'T1')

      expect(evidence_request_query['idRequeteur']).to eq(Settings.public_demo_requester_id)
      expect(Demo::Request.sole.journey_id).to eq(journey(public_entrance).id)
    end

    it 'signs out of the real one back to the public sign-in page, the identity of the console held' do
      identify_demo_user
      identify_visitor(instance: real_france_connect)

      delete demonstration_identification_path(version: 'v2.0', procedure: 'T1')

      expect(response.headers['Location']).to start_with(FranceConnectStubs::REAL_END_SESSION_ENDPOINT)
      expect(request.session[:france_connect_logout_home]).to eq(demonstration_home_path(version: 'v2.0', procedure: 'T1'))
      expect(held_demo_identity(public_entrance)).to be_nil
      expect(held_demo_identity[:family_name]).to eq('Sørensen')
    end
  end

  it 'offers the real one alone, and departs nowhere else, where it alone is declared' do
    undeclare_france_connect('fake')
    declare_france_connect(real_france_connect)
    stub_code_list
    stub_demonstration_requirements

    get demonstration_home_path(version: 'v2.0', procedure: 'T1')
    expect(page.css('input[name=france_connect]').pluck('value')).to eq(%w[real])

    post demonstration_identification_path(version: 'v2.0', procedure: 'T1'), params: { france_connect: 'fake' }
    expect(response).to redirect_to(demonstration_home_path(version: 'v2.0', procedure: 'T1'))
    expect(session[:france_connect]).to be_nil
  end

  describe 'one browser walking both entrances' do
    before { sign_in }

    it 'brings each identification back to the documents page of the entrance it left from' do
      identify_visitor
      expect(response).to redirect_to(demonstration_documents_path(version: 'v2.0', procedure: 'T1'))

      identify_demo_user
      expect(response).to redirect_to(admin_demo_documents_path(version: 'v2.0', procedure: 'T1'))

      get admin_root_path
      expect(response).to have_http_status(:ok)
    end

    it 'keeps the identity, the journey and the cards of the console when the visitor identifies on the public site' do
      identify_demo_user
      console_journey = journey(Demo::Entrance::CONSOLE)
      Demo::Card.add(journey_id: console_journey.id, country_code: 'FR',
        requirement: build(:requirement, id: "https://sr.acc.oots.tech.ec.europa.eu/requirements/#{exigence}"))

      identify_visitor(userinfo: FranceConnectStubs::REQUESTED_USERINFO)

      expect(journey(Demo::Entrance::CONSOLE).id).to eq(console_journey.id)
      expect(Demo::Card.added(console_journey.id)).to be_present
      expect(held_demo_identity[:family_name]).to eq('Sørensen')
      expect(held_demo_identity(public_entrance)[:family_name]).to eq('Dupont')
      expect(journey(public_entrance).id).not_to eq(console_journey.id)
    end

    it 'brings the sign-out of FranceConnect+ back to the public sign-in page, the session of the agent held' do
      identify_visitor

      delete demonstration_identification_path(version: 'v2.0', procedure: 'T1')
      expect(held_demo_identity(public_entrance)).to be_nil
      expect(request.session[:france_connect_logout_home]).to eq(demonstration_home_path(version: 'v2.0', procedure: 'T1'))

      get '/demo/franceconnect/retour_deconnexion', params: { state: request.session[:france_connect_logout] }
      expect(response).to redirect_to(demonstration_home_path(version: 'v2.0', procedure: 'T1'))

      get admin_root_path
      expect(response).to have_http_status(:ok)
    end
  end

  it 'forgets the identity of the visitor when an agent signs in to the console in the same browser' do
    identify_visitor

    sign_in

    expect(held_demo_identity(public_entrance)).to be_nil
  end

  describe 'a refused identification' do
    before do
      stub_code_list
      stub_demonstration_requirements
    end

    it 'sends the visitor back to the public sign-in page it left from' do
      depart_from_demo_home(stub_france_connect, entrance: public_entrance)

      get '/demo/franceconnect/retour_connexion', params: { error: 'access_denied' }

      expect(response).to redirect_to(demonstration_home_path(version: 'v2.0', procedure: 'T1'))
    end

    it 'sends a return this browser never asked for to the public site, the one a browser without a session reaches' do
      get '/demo/franceconnect/retour_connexion', params: { error: 'access_denied' }

      expect(response).to redirect_to('/demonstration')
    end

    it 'sends it to the console where the public site is closed' do
      undeclare_france_connect('fake')

      get '/demo/franceconnect/retour_connexion', params: { error: 'access_denied' }

      expect(response).to redirect_to(admin_demo_root_path)
    end
  end

  describe 'the request' do
    before do
      identify_visitor
      stub_documents_page
      stub_oots_france_public_keys
      stub_evidence_request
      stub_exchange_state
    end

    it 'goes out under the requester of the public site' do
      get demonstration_documents_path(version: 'v2.0', procedure: 'T1')
      post demonstration_demande_path(exigence:, type: named_type(exigence), version: 'v2.0', procedure: 'T1')

      expect(evidence_request_query['idRequeteur']).to eq(Settings.public_demo_requester_id)
      expect(Demo::Request.sole.journey_id).to eq(journey(public_entrance).id)
    end

    it 'serves the evidence as the console does: a PDF in place, any other format for saving' do
      get demonstration_documents_path(version: 'v2.0', procedure: 'T1')
      post demonstration_demande_path(exigence:, type: named_type(exigence), version: 'v2.0', procedure: 'T1')
      justificatif = demonstration_justificatif_path(exigence:, version: 'v2.0', procedure: 'T1',
        type: Demo::Card.sole.named_evidences.sole.evidence_type_uuid)

      Demo::Request.sole.receive_evidence!("%PDF-1.4\ndrapeau".b, EvidenceType::PDF)
      get justificatif
      expect(response.headers['Content-Disposition']).to start_with('inline').and include('document.pdf')

      Demo::Request.sole.receive_evidence!('<statut>inscrit</statut>', 'application/xml')
      get justificatif
      expect(response.headers['Content-Disposition']).to start_with('attachment').and include('document.xml')
    end

    it 'names the procedure its own documents page showed, whatever the console showed since in the same browser' do
      sign_in
      identify_demo_user
      identify_visitor
      stub_code_list(procedures: { 'T1' => 'Le titre que le site public affiche' })
      get demonstration_documents_path(version: 'v2.0', procedure: 'T1')

      stub_code_list(procedures: { 'T1' => 'Le titre que la console affiche' })
      get admin_demo_documents_path(version: 'v2.0', procedure: 'T1')
      post demonstration_demande_path(exigence:, type: named_type(exigence), version: 'v2.0', procedure: 'T1')

      expect(Demo::Request.sole.procedure_name).to eq('Le titre que le site public affiche')
    end
  end
end
