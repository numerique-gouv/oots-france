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
    # request matching the one the eID means yielded.
    it 'offers no field on any attribute of the identity' do
      get admin_demo_demande_path

      expect(response.parsed_body.css('main input, main select, main textarea')).to be_empty
    end

    # The pseudonym is FranceConnect+'s own, per service provider, and showing it
    # beside a missing eIDAS identifier invites exactly the confusion RG5 forbids.
    it 'never shows the pseudonym FranceConnect+ hands the procedure' do
      get admin_demo_demande_path

      expect(response.body).not_to include(FranceConnectStubs::DANISH_USERINFO.fetch('sub'))
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
