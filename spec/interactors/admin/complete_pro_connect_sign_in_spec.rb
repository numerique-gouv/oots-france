require 'rails_helper'

RSpec.describe Admin::CompleteProConnectSignIn do
  let!(:instance) { stub_pro_connect }
  let(:expected) { { 'state' => 's' * 32, 'nonce' => 'le-nonce-de-depart' } }

  def complete
    described_class.call(instance:, expected:, code: 'un-code', state: 's' * 32)
  end

  before { stub_pro_connect_tokens(signed_by_pro_connect(pro_connect_id_token_claims)) }

  it 'answers the admitted agent and the ID Token' do
    result = complete

    expect(result).to be_success
    expect(result.agent.email).to eq(ProConnectStubs::AGENT_EMAIL)
    expect(result.id_token.split('.').size).to eq(3)
  end

  it 'refuses an agent outside the admitted domains, with the address and the ID Token' do
    stub_pro_connect_userinfo({ 'sub' => ProConnectStubs::AGENT_SUB, 'email' => 'agent@exemple.fr' })

    result = complete

    expect(result.error).to include(key: :agent_refused, email: 'agent@exemple.fr')
    expect(result.error[:id_token].split('.').size).to eq(3)
  end

  it 'refuses a UserInfo without an address' do
    stub_pro_connect_userinfo({ 'sub' => ProConnectStubs::AGENT_SUB }, form: :json)

    expect(complete.error).to include(key: :sign_in_failed, errors: [/aucune adresse/])
  end

  it 'refuses a return when ProConnect cannot be reached' do
    stub_request(:post, ProConnectStubs::TOKEN_ENDPOINT).to_timeout

    expect(complete.error[:key]).to eq(:sign_in_failed)
  end
end
