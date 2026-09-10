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

    it 'opens no exchange and asks the contract nothing' do
      expect { get admin_demo_confirmation_path }.not_to change(Exchange, :count)

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

    # Unable to name the two, it must not offer to confirm: requirement 27 makes
    # them a condition of the request, not a decoration on it.
    it 'offers nothing to confirm when the directories refuse' do
      stub_directory('dsd', 'dataservices-by-evidencetype', 'dsd_aucun_service_fr')

      get admin_demo_confirmation_path

      expect(response.parsed_body.css('main').text).to include('DSD:ERR:0001')
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

    it 'shows the exchange the contract opened' do
      post admin_demo_confirmation_path

      expect(response.parsed_body.css('main').text).to include(accepted_body.fetch(:echange))
    end

    # CA7: the demonstration fields are not the evidence, and nothing carries
    # them — the query string included.
    it 'carries none of the demonstration fields' do
      post admin_demo_confirmation_path

      expect(evidence_request_query.values.join).not_to include('4200')
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

    # CA9. Three refusals pronounced before any exchange exists, told apart by
    # the status alone, which is all a service provider's server has to go on.
    describe 'a refusal that opens nothing' do
      it 'says what the contract refused, with the message it returned' do
        stub_evidence_request(status: 422, body: { erreur: 'EB:ERR:0001 : requête invalide' }.to_json)

        expect { post admin_demo_confirmation_path }.not_to change(Exchange, :count)

        expect(response.parsed_body.css('main').text)
          .to include('refusée', 'EB:ERR:0001', "Aucun échange n'a été ouvert")
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

      it 'holds no conversation to reuse after a refusal' do
        stub_evidence_request(status: 502, body: { erreur: 'Annuaire injoignable' }.to_json)
        post admin_demo_confirmation_path

        stub_evidence_request
        post admin_demo_confirmation_path

        expect(evidence_request_query).not_to have_key('idConversation')
      end
    end
  end

  # The session is the operator's, and `Demo::UserIdentity.from_session` answers
  # `nil` to anything it can no longer read.
  def reset_session_identity
    allow(Demo::UserIdentity).to receive(:from_session).and_return(nil)
  end
end
