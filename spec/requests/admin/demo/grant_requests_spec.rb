require 'rails_helper'

RSpec.describe 'Admin::Demo::GrantRequests' do
  before { sign_in }

  describe 'GET /admin/demo/demande, once identified' do
    before { identify_demo_user }

    # CA2: the minimum data set, as the authentication gave it.
    it 'shows the name, the given name and the date of birth received' do
      get admin_demo_demande_path

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.css('main').text).to include('Sørensen', 'Freja Marie', '2001-04-17')
    end

    # CA3: what the authentication attested, which is the level and the path.
    it 'shows the level of assurance reached and where the identity came from' do
      get admin_demo_demande_path

      expect(response.parsed_body.css('main').text).to include('Substantial', 'autre État membre', 'eIDAS')
    end

    # CA5: no claim carries one, and the screen says so rather than leaving a gap.
    it 'says the eIDAS identifier was not returned' do
      get admin_demo_demande_path

      expect(response.parsed_body.css('main').text).to include('Non rendu')
    end

    # CA10, first half.
    it 'shows the two optional attributes when they were received' do
      get admin_demo_demande_path

      expect(response.parsed_body.css('main').text).to include('Féminin', 'Aarhus')
    end

    it 'shows neither when neither was received' do
      identify_demo_user(userinfo: FranceConnectStubs::DANISH_USERINFO.except('gender', 'birthplace'))

      get admin_demo_demande_path

      expect(response.parsed_body.css('main').text).not_to include('Aarhus')
      expect(response.parsed_body.css('main').text).not_to include('Sexe')
    end

    # CA4: chapter 2.2 §2 makes the portal answerable for the identity in the
    # request matching the one the eID means yielded. The application's own
    # fields sit outside these tables, and the assertion is on the tables alone.
    it 'offers no field on any attribute of the identity' do
      get admin_demo_demande_path

      expect(response.parsed_body.css('main table input, main table select, main table textarea')).to be_empty
    end

    # RG1 of OOTS-181, chapter 1 §3.3: the user is asked to express explicitly
    # whether the system is to be used, so the question is on the form and both
    # answers are offered.
    it 'asks the user to say whether the evidence is to be fetched' do
      get admin_demo_demande_path

      expect(response.parsed_body.css('main input[name="oots"]').pluck('value'))
        .to contain_exactly('oui', 'non')
    end

    # The pseudonym is FranceConnect+'s own, per service provider, and showing it
    # beside a missing eIDAS identifier invites exactly the confusion RG5 forbids.
    it 'never shows the pseudonym FranceConnect+ hands the procedure' do
      get admin_demo_demande_path

      expect(response.body).not_to include(FranceConnectStubs::DANISH_USERINFO.fetch('sub'))
    end
  end

  describe 'POST /admin/demo/demande' do
    before { identify_demo_user }

    # CA1: without the explicit request, the journey stops here — nothing is
    # resolved and nothing is asked of anyone. What proves it is where the
    # answer leads, this action being the only thing between the two.
    it 'says the evidence has to come by another route' do
      post admin_demo_demande_path, params: { oots: 'non' }

      expect(response.parsed_body.css('main').text).to include('Justificatif à fournir vous-même')
    end

    # An unanswered form is the absence of the gesture, which is the reading the
    # chapter's « whether » asks for.
    it 'treats an unanswered question as no request at all' do
      post admin_demo_demande_path

      expect(response.parsed_body.css('main').text).to include('Justificatif à fournir vous-même')
    end

    it 'leads to the confirmation when the user did ask for OOTS' do
      post admin_demo_demande_path, params: { oots: 'oui' }

      expect(response).to redirect_to(admin_demo_confirmation_path)
    end

    # CA7: the application's own fields are a demonstration and nothing reads
    # them — no column holds them, and the request carries none.
    it 'keeps nothing of the demonstration fields' do
      post admin_demo_demande_path,
        params: { oots: 'oui', montant: '4200', annee: '2026-2027', motif: 'Bourse sur critères sociaux' }

      expect(AuditEvent.pluck(:detail).join).not_to include('4200')
      expect(session[:demo_identity].to_s).not_to include('4200')
    end
  end

  describe 'GET /admin/demo/demande with no identity held' do
    it 'sends the operator back to the start of the procedure' do
      get admin_demo_demande_path

      expect(response).to redirect_to(admin_demo_root_path)
    end

    # The same validity on the way out as on the way in: a session written under
    # an earlier shape would otherwise render as a form with blank rows.
    it 'sends the operator back when what the session holds is no longer a valid identity' do
      identify_demo_user
      allow(Demo::UserIdentity).to receive(:from_session).and_return(Demo::UserIdentity.new)

      get admin_demo_demande_path

      expect(response).to redirect_to(admin_demo_root_path)
    end
  end

  # CA7: the demonstration's session is the operator's, and one ends with the other.
  describe 'once the operator has signed out' do
    it 'holds no identity for the next session' do
      identify_demo_user
      delete admin_session_path

      sign_in
      get admin_demo_demande_path

      expect(response).to redirect_to(admin_demo_root_path)
    end
  end
end
