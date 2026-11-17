require 'rails_helper'

# The preview space for « FR - Student status (MESRI) »: the data shown rather
# than a document offered (RG10), and the page a failing registry leaves
# (RG16).
RSpec.describe 'The preview space for the student status' do
  include ActiveJob::TestHelper

  let(:page) { response.parsed_body }
  let(:martin_jacques) do
    FranceConnectStubs::REQUESTED_USERINFO.merge('given_name' => 'Jacques', 'family_name' => 'Martin',
      'birthdate' => '2004-01-01', 'gender' => 'male', 'birthplace' => '75102')
  end

  def segment = session.specification.segment

  def space_path(params = {}) = preview_session_path(segment, session.token, params)

  def identify(params = {}) = identify_in_preview_space(space_path(params), userinfo: martin_jacques)

  def visit_space(params = {})
    get space_path(params)
    follow_redirect! if response.redirect?
  end

  def heading = page.at_css('h1').text

  describe 'a status found' do
    let!(:session) do
      create(:preview_session, first_request: student_status_request(flag: 'true').raw,
        document: Base64.strict_encode64(ApiParticulierStubs::MARTIN_JACQUES.to_json))
    end

    # CA8.
    it 'shows the data itself, and offers no document' do
      identify
      visit_space(locale: 'en')

      expect(page.text).to include('Martin', 'Jacques', '2004-01-01', 'Université Paris Nanterre', '0330023W',
        '2024-10-01', '2025-08-31', 'Enrolled', 'formation initiale', '92000')
      expect(page.css('a[href$="/document"]')).to be_empty
      expect(page.css('input[type=radio]').pluck('value')).to eq(PreviewSession::DECISIONS)
    end

    it 'shows the identity in the card of an identity, under the registry\'s names and nothing else' do
      identify
      visit_space

      card = page.at_css('main .identity-card')
      expect(card.css('dt').map { |node| node.text.strip }).to eq(['Nom de naissance', 'Prénom', 'Date de naissance'])
      expect(card.css('dd').map { |node| node.text.strip }).to eq(%w[Martin Jacques 2004-01-01])
      expect(card.css('.identity-card__level, .identity-card__action')).to be_empty
    end

    it 'shows nothing before the user identifies' do
      stub_france_connect(userinfo: martin_jacques)
      get space_path

      expect(response).to be_redirect
      expect(response.body).not_to include('Nanterre')
    end

    it 'serves no document' do
      identify
      get preview_session_document_path(segment, session.token)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'a status whose identity the registry gives in part' do
    let!(:session) do
      partial = ApiParticulierStubs::MARTIN_JACQUES.merge(
        'identite' => ApiParticulierStubs::MARTIN_JACQUES['identite'].merge('prenom' => nil),
      )
      create(:preview_session, first_request: student_status_request(flag: 'true').raw,
        document: Base64.strict_encode64(partial.to_json))
    end

    it 'gives the missing attribute no row, and still offers the choice' do
      identify
      visit_space

      card = page.at_css('main .identity-card')
      expect(card.css('dt').map { |node| node.text.strip }).to eq(['Nom de naissance', 'Date de naissance'])
      expect(page.css('input[type=radio]').pluck('value')).to eq(PreviewSession::DECISIONS)
    end
  end

  # CA21: a person admitted without being enrolled is shown as such.
  describe 'a status found for a person only admitted' do
    let!(:session) do
      admission = ApiParticulierStubs::MARTIN_JACQUES['admissions'].first.merge(
        'est_inscrit' => false, 'etablissement_etudes' => { 'uai' => '0331023W', 'nom' => 'Université Paris Saclay' },
      )
      create(:preview_session, first_request: student_status_request(flag: 'true').raw,
        document: Base64.strict_encode64(ApiParticulierStubs::MARTIN_JACQUES.merge('admissions' => [admission]).to_json))
    end

    it 'says the admission is not an enrolment' do
      identify
      visit_space(locale: 'en')

      expect(page.text).to include('Université Paris Saclay', 'Admitted')
      expect(page.text).not_to include('Enrolled')
    end
  end

  # The attestation, offered as any PDF, and nothing of the data beside it.
  describe 'a status found as an attestation' do
    let!(:session) do
      create(:preview_session, first_request: student_status_request(flag: 'true', formats: [EvidenceType::PDF]).raw,
        document: Base64.strict_encode64(ApiParticulierStubs::ATTESTATION))
    end

    it 'offers the attestation alone, without the data' do
      identify
      visit_space

      expect(page.text).not_to include('Université Paris Nanterre', '0330023W')
      expect(page.at_css('a[href$="/document"]').text)
        .to eq(I18n.t('preview_sessions.show.open.consult', size: '43 octets'))
    end

    it 'serves the attestation API Particulier generated' do
      identify
      get preview_session_document_path(segment, session.token)

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq('application/pdf')
      expect(response.body.b).to eq(ApiParticulierStubs::ATTESTATION)
    end
  end

  # CA12, on the space: the registry asked once the user is back.
  describe 'a status to look up once the user identifies' do
    let!(:session) do
      create(:preview_session, :unmatched, unmatched: false, lookup_pending: true,
        first_request: student_status_request(gender: nil, flag: 'false').raw)
    end

    it 'asks API Particulier with the sex FranceConnect+ returned, and shows what it found' do
      stub_student_status
      identify
      visit_space

      expect(student_status_asked(ApiParticulierStubs::MARTIN_JACQUES_QUERY.merge(
        'sexeEtatCivil' => 'M', 'codeCogInseeCommuneNaissance' => '75102',
      ))).to have_been_made.once
      expect(page.text).to include('Université Paris Nanterre')
    end

    it 'says no document matches a user API Particulier does not know' do
      stub_student_status_unknown
      identify
      visit_space

      expect(heading).to eq('Aucun document ne vous correspond')
    end

    # CA14.
    describe 'when API Particulier fails' do
      before { stub_student_status(status: 502, body: '{}') }

      it 'says the document cannot be provided, in the language chosen, and shows nothing of it' do
        identify
        visit_space(locale: 'en')

        expect(heading).to eq('The document cannot be provided')
        expect(page.text).to include('The French administration could not obtain this document. No document will ' \
                                     'be sent to your procedure, which will be informed.')
        expect(page.css('input[type=radio], a[href$="/document"]')).to be_empty
        expect(page.text).not_to include('Nanterre')
        expect(page.text).to include(I18n.t('preview_sessions.return.awaiting', locale: :en))
      end

      it 'offers the way back once the second request brought it, without taking it' do
        identify
        session.reload.update!(return_location: 'https://portail.example/retour')
        visit_space

        expect(page.at_css('a.fr-btn')['href']).to eq('https://portail.example/retour')
        expect(response).to have_http_status(:ok)
      end

      it 'says the same on a revisit, without asking again nor sending the user to identify' do
        identify
        visit_space
        get space_path

        expect(response).to have_http_status(:ok)
        expect(heading).to eq('Le document ne peut pas être fourni')
        expect(a_request(:get, student_status_endpoint)).to have_been_made.once
      end

      describe 'on the 1.2 line' do
        let!(:session) do
          create(:preview_session, :unmatched, :legacy_line, unmatched: false, lookup_pending: true,
            first_request: student_status_request(gender: nil, line: :v1_2).raw)
        end

        it 'offers the way back the visit brought' do
          identify({ returnurl: 'https://portail.example/retour' })
          visit_space

          expect(page.at_css('a.fr-btn')['href']).to eq('https://portail.example/retour')
        end
      end
    end
  end
end
