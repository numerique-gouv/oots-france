require 'rails_helper'

RSpec.describe 'Admin::Demo::Home' do
  let(:name) { CodeListStubs::STUDY_FINANCING_NAME }

  describe 'GET /admin/demo' do
    before do
      sign_in
      stub_code_list(
        procedures: { ProcedureCode::STUDY_FINANCING => CodeListStubs::STUDY_FINANCING_LABEL },
        procedure_names: { ProcedureCode::STUDY_FINANCING => name },
      )
      stub_demonstration_requirements
      declare_france_connect(fake_france_connect)
    end

    # The title France declared the procedure under, and not the SDG one: a
    # member state names its own procedure, and that name is what its portal
    # would show. Marked `EN`, the language the directory published it in.
    it 'stands under the title France declared the procedure under' do
      get admin_demo_root_path

      expect(response).to have_http_status(:ok)
      expect(seen_in('h1')).to eq('🇫🇷 T1 Apply for funding for higher education')
      expect(response.parsed_body.at_css('h1 .directory-value')['lang']).to eq('EN')
    end

    # The SDG title stands in when the directory says nothing: the two live on
    # hosts of their own, and one being down is not the other being down.
    it 'falls back on the title the code list publishes when the directory says nothing' do
      stub_request(:get, "#{DirectoryStubs::ACCEPTANCE}/eb/rest/search")
        .with(query: hash_including({})).to_timeout

      get admin_demo_root_path

      expect(seen_in('h1')).to eq("🇫🇷 T1 #{name}")
      expect(response.parsed_body.at_css('h1 .directory-value')['lang']).to eq('en')
    end

    # The first of the Evidence Broker's two queries (chapter 3.2.4), asked in
    # France's own jurisdiction: the procedure is ours, the evidence types
    # satisfying it belong to whoever is asked for them, and this page asks for
    # none.
    it 'lists what the Evidence Broker publishes for the procedure, in English' do
      get admin_demo_root_path

      expect(response.parsed_body.css('main li .directory-value').map { |value| seen(value) })
        .to eq(['(TEST) Test Requirement 2', 'Proof of enrolment in academic tertiary education'])
      expect(response.parsed_body.at_css('main li .directory-value')['lang']).to eq('EN')
      expect(a_request(:get, "#{DirectoryStubs::ACCEPTANCE}/eb/rest/search")
        .with(query: hash_including('procedure-id' => 'T1', 'country-code' => 'FR'))).to have_been_made
    end

    # Chapter 1 §3.3 makes the request conditional on the user asking for it,
    # and the page says so before anyone has clicked anything.
    it 'says what the procedure can do, and that nothing leaves without a word from the user' do
      get admin_demo_root_path

      expect(response.parsed_body.css('main').text)
        .to include('directly from the administration', 'without your explicit agreement')
    end

    it 'asks the Evidence Broker for nothing else: no evidence type, no provider' do
      get admin_demo_root_path

      expect(a_request(:get, "#{DirectoryStubs::ACCEPTANCE}/eb/rest/search")
        .with(query: hash_including('queryId' => a_string_including('evidence-types-by-requirement'))))
        .not_to have_been_made
    end

    # The way in is the one thing this page is for, and it needs no directory.
    it 'stands, and still offers the way in, when the Evidence Broker cannot be reached' do
      stub_request(:get, "#{DirectoryStubs::ACCEPTANCE}/eb/rest/search")
        .with(query: hash_including({})).to_timeout

      get admin_demo_root_path

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.css('main li .directory-value')).to be_empty
      expect(response.parsed_body.css('main').text).not_to include('Documents to be retrieved')
      expect(response.parsed_body.css('main button.fr-btn')).to be_present
    end

    # A refusal is not an outage: chapter 3.2.4 has a directory with nothing to
    # give refuse rather than answer empty, and that refusal carries a code, so
    # it never becomes the `CommonServicesError` the rescue above catches. The
    # page stands all the same, on the title the code list publishes.
    it 'stands, and still offers the way in, when the Evidence Broker refuses' do
      stub_directory('eb', 'requirements-by-procedure', 'eb_requirements_vides')

      get admin_demo_root_path

      expect(response).to have_http_status(:ok)
      expect(seen(response.parsed_body.at_css('main h1'))).to include(CodeListStubs::STUDY_FINANCING_NAME)
      expect(response.parsed_body.css('main li .directory-value')).to be_empty
      expect(response.parsed_body.css('main button.fr-btn')).to be_present
    end

    # CA2: a fresh clone declares the fake and nothing else, so the page offers
    # the one button — and `make setup` leaves the three variables of the real
    # one empty, which is what makes that the default rather than an arrangement.
    it 'offers one button per FranceConnect+ declared, and none for one that is not' do
      get admin_demo_root_path

      expect(seen_all('main button.fr-btn')).to eq(['🇪🇺 Choose a country to sign-in (mocked)'])
      expect(response.parsed_body.css('main form').pluck('action'))
        .to include(admin_demo_identification_path)
    end

    # The way in is introduced by a heading and a sentence, in English, since
    # the reader is a user of another Member State.
    it 'invites the user to sign in to start the procedure' do
      get admin_demo_root_path

      expect(seen_all('main h2')).to include('Sign-in to start the procedure')
      expect(response.parsed_body.css('main').text)
        .to include('Use your European identity to sign-in.',
          'even different states than the one you chose to sign-in with.')
    end

    # CA1: the two buttons, the real FranceConnect+ first, the fake saying it is
    # one. Criterion 11.9 of the RGAA: two buttons reading alike and leading
    # elsewhere are not « pertinents » one without the other.
    it 'offers a button per FranceConnect+ when the deployment declares both, the real first' do
      declare_france_connect(real_france_connect)

      get admin_demo_root_path

      expect(seen_all('main button.fr-btn'))
        .to eq(['🇪🇺 Choose a country to sign-in', '🇪🇺 Choose a country to sign-in (mocked)'])
    end

    # Neither is the page's main action — that is the request, two pages on —
    # and the fake stands one step behind the real: secondary, then tertiary.
    it 'ranks the real FranceConnect+ secondary and the fake tertiary' do
      declare_france_connect(real_france_connect)

      get admin_demo_root_path

      expect(response.parsed_body.css('main button.fr-btn').pluck('class'))
        .to eq(['fr-btn fr-btn--secondary', 'fr-btn fr-btn--tertiary'])
    end

    # RG2: the name of the FranceConnect+ travels in the body of the submission
    # the button already is — a `POST`, because starting the flow writes the
    # `state` and the `nonce` its return is checked against.
    it 'lets each button name its own FranceConnect+ in the body of its submission' do
      declare_france_connect(real_france_connect)

      get admin_demo_root_path

      expect(response.parsed_body.css('main form input[name=france_connect]').pluck('value'))
        .to eq(%w[real fake])
      expect(response.parsed_body.css('main form').pluck('method').uniq).to eq(['post'])
    end

    # The demonstration plays a Danish student and nothing else: the French
    # identity of FranceConnect+ has no button here. Every way in the page
    # offers opens the European flow.
    it 'carries no FranceConnect+ button of its own' do
      declare_france_connect(real_france_connect)

      get admin_demo_root_path

      expect(response.parsed_body.css('main form').pluck('action').uniq)
        .to eq([admin_demo_identification_path])
    end

    # A name is an ornament here as everywhere else in the console: the code
    # list lives on a host of its own, and the page says what it says without it.
    it 'stands without either source of a title' do
      stub_request(:get, CodeListClient::PROCEDURES).to_timeout
      stub_request(:get, "#{DirectoryStubs::ACCEPTANCE}/eb/rest/search")
        .with(query: hash_including({})).to_timeout

      get admin_demo_root_path

      expect(response).to have_http_status(:ok)
      expect(seen_in('h1')).to eq('🇫🇷 T1 Aucun label')
      expect(response.parsed_body.css('h1 .directory-value')).to be_empty
    end
  end

  def seen_in(selector) = seen(response.parsed_body.at_css(selector))

  def seen_all(selector) = response.parsed_body.css(selector).map { |node| seen(node) }

  describe 'GET /admin/demo without a session' do
    it 'sends the visitor to the login page' do
      get admin_demo_root_path

      expect(response).to redirect_to(new_admin_session_path)
    end
  end
end
