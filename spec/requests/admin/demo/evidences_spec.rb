require 'rails_helper'

RSpec.describe 'Admin::Demo::Evidences' do
  let(:content) { "%PDF-1.4\ndrapeau".b }
  # The one requirement `eb_requirements_fr` holds. A document is offered per
  # requirement asked for, and the address of each names its own.
  let(:exigence) { '00000000-0000-0000-0000-000000000000' }

  before do
    sign_in
    identify_demo_user
    stub_oots_france_public_keys
    stub_evidence_request
    stub_directory_resolution
    stub_directory('eb', 'requirements-by-procedure', 'eb_requirements_fr')
    stub_directory('eb', 'evidence-types-by-requirement', 'eb_evidence_types_fi')
    stub_directory('dsd', 'dataservices-by-evidencetype', 'dsd_data_services_fi')
    stub_code_list
    # Requirement 27 of chapter 1 §2: the press exists only once the page has
    # named the evidence type and the provider, so the journey is walked whole.
    stub_exchange_state
    get admin_demo_documents_path
    post demande_path
  end

  describe 'GET /admin/demo/justificatif' do
    before { Demo::Request.sole.receive_evidence!(content) }

    # CA1, second half. Chapter 1 §4.2: the user « cannot modify its content in
    # any way », so the bytes are served as they arrived, and their digest is
    # the digest of what was delivered.
    it 'serves the evidence byte for byte, under its own type' do
      get justificatif_path

      expect(response.media_type).to eq(Attachment::MIME_TYPE)
      expect(response.body.b).to eq(content)
      expect(Digest::SHA256.hexdigest(response.body.b)).to eq(Demo::Request.sole.evidence_digest)
      # `send_data` defaults to `attachment`: without this, a return to that
      # default would pass every assertion above while making the user download
      # what the chapter has them read and decide on.
      expect(response.headers['Content-Disposition']).to start_with('inline')
    end

    it 'sends an operator holding no identity back to the start' do
      allow(Demo::UserIdentity).to receive(:from_session).and_return(nil)

      get justificatif_path

      expect(response).to redirect_to(admin_demo_root_path)
    end

    # Chapter 1 §4.2 makes the evidence available to « the specific procedure
    # end-user that issued the query for those evidences »: another session
    # follows another exchange, and this row is not on its way.
    it 'serves nothing to a session that has moved on to another request' do
      stub_evidence_request(body: { echange: 'un-second-echange',
                                    conversation: DemoContractStubs::ACCEPTED_CONVERSATION,
                                    statut: 'pending' }.to_json)
      stub_exchange_state('un-second-echange', statut: 'pending')
      post demande_path

      get justificatif_path

      expect(response).to redirect_to(admin_demo_documents_path)
    end
  end

  # Une session qui nomme un échange dont le registre n'a plus la ligne :
  # `demo_request` vaut alors `nil`, et c'est le cas pour lequel la navigation
  # sûre du contrôleur existe. Rien ne l'atteignait.
  it 'sends the operator back when the register no longer holds the request' do
    forget_the_request

    get justificatif_path

    expect(response).to redirect_to(admin_demo_documents_path)
  end

  # Chapter 1 §4.2 makes the evidence available to « the specific procedure
  # end-user that issued the query », and the parameter only says which of that
  # user's requests is meant: one it does not name is one the session never
  # followed, whatever the register holds.
  describe 'a requirement the session followed no request for' do
    before { Demo::Request.sole.receive_evidence!(content) }

    it 'serves nothing for a requirement the session never asked about' do
      get justificatif_path('11111111-2222-3333-4444-555555555555')

      expect(response).to redirect_to(admin_demo_documents_path)
    end

    it 'serves nothing when no requirement is named at all' do
      get admin_demo_justificatif_path

      expect(response).to redirect_to(admin_demo_documents_path)
    end
  end

  it 'sends the operator back to the page the document is offered from while nothing has been delivered' do
    get justificatif_path

    expect(response).to redirect_to(admin_demo_documents_path)
  end

  # La ligne s'en va, la session garde l'identifiant : c'est cet écart que la
  # navigation sûre d'`EvidencesController` absorbe.
  def forget_the_request
    Demo::Request.delete_all
  end

  def demande_path(uuid = exigence) = admin_demo_demande_path(exigence: uuid)

  def justificatif_path(uuid = exigence) = admin_demo_justificatif_path(exigence: uuid)
end
