require 'rails_helper'

RSpec.describe Demo::RequestEvidence do
  subject(:result) do
    described_class.call(identity:, conversation_id: nil, evidence_request_client: client, token_writer:)
  end

  let(:identity) { Demo::UserIdentity.new(family_name: 'Sørensen') }
  let(:token_writer) { instance_double(Demo::BeneficiaryTokenWriter, call: 'un-jeton-chiffré') }
  let(:client) { instance_double(Demo::EvidenceRequestClient, fetch: answer) }
  let(:answer) do
    Demo::ContractAnswer.new(status: 202, payload: { 'echange' => 'un-échange', 'conversation' => 'une-conversation' })
  end

  it 'asks for the study financing in France, the demonstration making France talk to France' do
    result

    expect(client).to have_received(:fetch).with(
      hash_including(requester_id: Settings.demo_requester_id, procedure_code: 'T1', country_code: 'FR'),
    )
  end

  it 'keeps the two identifiers the acceptance returned' do
    expect(result).to have_attributes(success?: true, exchange_id: 'un-échange', conversation_id: 'une-conversation')
  end

  describe 'the refusals told apart by status' do
    {
      422 => :demo_refused,
      501 => :demo_locked,
      502 => :demo_unreachable,
      500 => :demo_unexpected,
    }.each do |status, key|
      it "answers #{status} with #{key}" do
        allow(client).to receive(:fetch)
          .and_return(Demo::ContractAnswer.new(status:, payload: { 'erreur' => 'ce qui a été rendu' }))

        expect(result.error).to include(key:)
      end
    end
  end

  # `EB:ERR:0001` travels in the message and never in the status, so the message
  # has to reach the page whichever refusal it was.
  it 'carries the message the contract returned' do
    allow(client).to receive(:fetch)
      .and_return(Demo::ContractAnswer.new(status: 422, payload: { 'erreur' => 'EB:ERR:0001 : refus' }))

    expect(result.error[:errors]).to include('EB:ERR:0001 : refus')
  end

  # The one refusal whose wording cannot name what happened.
  it 'spells out the status of an answer it has no sentence for' do
    allow(client).to receive(:fetch).and_return(Demo::ContractAnswer.new(status: 500))

    expect(result.error[:errors]).to eq(['500'])
  end

  it 'reports a contract it could not reach at all as unreachable' do
    allow(client).to receive(:fetch).and_raise(Faraday::ConnectionFailed, 'connexion refusée')

    expect(result.error).to include(key: :demo_unreachable)
  end
end
