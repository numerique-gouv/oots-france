require 'rails_helper'

RSpec.describe Demo::EvidenceRequestClient do
  subject(:answer) do
    described_class.new.fetch(
      requester_id: '00000000000003', procedure_code: 'T1', country_code: 'FR',
      encrypted_beneficiary: 'un-jeton-chiffré', conversation_id:,
    )
  end

  let(:conversation_id) { nil }

  before { stub_evidence_request }

  it 'asks the contract under the query string a service provider sends' do
    answer

    expect(evidence_request_query).to eq(
      'idRequeteur' => '00000000000003', 'codeDemarche' => 'T1', 'codePays' => 'FR',
      'beneficiaire' => 'un-jeton-chiffré', 'previsualisationRequise' => 'false',
    )
  end

  # `EvidenceRequestsController` reads a bare `previsualisationRequise` as true,
  # so the demonstration writes the value out rather than omitting it.
  it 'asks for the evidence itself and not for a preview' do
    answer

    expect(evidence_request_query['previsualisationRequise']).to eq('false')
  end

  it 'names no conversation when it holds none' do
    answer

    expect(evidence_request_query).not_to have_key('idConversation')
  end

  context 'when a conversation is already under way' do
    let(:conversation_id) { 'bbbbbbbb-0000-4000-8000-000000000001' }

    it 'names it, so the two requests are known to be the same user’s' do
      answer

      expect(evidence_request_query['idConversation']).to eq(conversation_id)
    end
  end

  it 'reads the two identifiers the acceptance returns' do
    expect(answer).to have_attributes(
      accepted?: true,
      exchange_id: accepted_body.fetch(:echange),
      conversation_id: accepted_body.fetch(:conversation),
    )
  end

  describe 'a refusal' do
    it 'is an answer and not an exception: the page has to show it' do
      stub_evidence_request(status: 422, body: { erreur: 'EB:ERR:0001' }.to_json)

      expect(answer).to have_attributes(accepted?: false, status: 422, error: 'EB:ERR:0001')
    end

    # The feature switch answers `Not Implemented Yet!` as plain text, and a
    # client that parsed unconditionally would raise on the one refusal a
    # deployment produces on purpose.
    it 'bears a body that is no JSON at all' do
      stub_evidence_request(status: 501, body: 'Not Implemented Yet!')

      expect(answer).to have_attributes(accepted?: false, status: 501, error: nil)
    end
  end
end
