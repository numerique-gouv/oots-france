require 'rails_helper'

RSpec.describe 'Admin::Demo::Evidences' do
  let(:content) { "%PDF-1.4\ndrapeau".b }

  before do
    sign_in
    identify_demo_user
    stub_oots_france_public_keys
    stub_evidence_request
    post admin_demo_confirmation_path
  end

  describe 'GET /admin/demo/suivi/justificatif' do
    before { Demo::Request.sole.receive_evidence!(content) }

    # CA1, second half. Chapter 1 §4.2: the user « cannot modify its content in
    # any way », so the bytes are served as they arrived, and their digest is
    # the digest of what was delivered.
    it 'serves the evidence byte for byte, under its own type' do
      get admin_demo_suivi_justificatif_path

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

      get admin_demo_suivi_justificatif_path

      expect(response).to redirect_to(admin_demo_root_path)
    end

    # Chapter 1 §4.2 makes the evidence available to « the specific procedure
    # end-user that issued the query for those evidences »: another session
    # follows another exchange, and this row is not on its way.
    it 'serves nothing to a session that has moved on to another request' do
      stub_evidence_request(body: { echange: 'un-second-echange',
                                    conversation: DemoContractStubs::ACCEPTED_CONVERSATION,
                                    statut: 'pending' }.to_json)
      post admin_demo_confirmation_path

      get admin_demo_suivi_justificatif_path

      expect(response).to redirect_to(admin_demo_suivi_path)
    end
  end

  it 'sends the operator back to the tracking while nothing has been delivered' do
    get admin_demo_suivi_justificatif_path

    expect(response).to redirect_to(admin_demo_suivi_path)
  end
end
