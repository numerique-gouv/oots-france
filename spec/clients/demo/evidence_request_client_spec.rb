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
      'beneficiaire' => 'un-jeton-chiffré', 'previsualisationRequise' => 'true',
    )
  end

  # SDG regulation, article 14(3)(f): the possibility to preview is the user's
  # right, and no law exempts this procedure from it.
  it 'lets the user preview the evidence' do
    answer

    expect(evidence_request_query['previsualisationRequise']).to eq('true')
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

  it 'names no evidence type when the card named none' do
    answer

    expect(evidence_request_query).not_to have_key('idTypeJustificatif')
  end

  it 'sends the answers the card was resolved on, one per question, and none where it asked nothing' do
    described_class.new.fetch(requester_id: '00000000000003', procedure_code: 'T1', country_code: 'EL',
      encrypted_beneficiary: 'un-jeton-chiffré', provider_classifications: { '1254f10f-406e-4f28-b1ba-d107b93fa264' => 'TC03' })

    expect(evidence_request_query['classificationFournisseur']).to eq('1254f10f-406e-4f28-b1ba-d107b93fa264' => 'TC03')

    answer
    expect(evidence_request_query).not_to have_key('classificationFournisseur')
  end

  it 'names the evidence type the card named, whole' do
    described_class.new.fetch(requester_id: '00000000000003', procedure_code: 'T1', country_code: 'AT',
      encrypted_beneficiary: 'un-jeton-chiffré', evidence_type_id: 'https://sr/AT/198ab7cc')

    expect(evidence_request_query['idTypeJustificatif']).to eq('https://sr/AT/198ab7cc')
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
