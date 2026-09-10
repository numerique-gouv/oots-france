require 'rails_helper'

RSpec.describe 'GET /demo/auth/cles_publiques' do
  subject(:published) { response.parsed_body['keys'].first }

  before { get '/demo/auth/cles_publiques' }

  # CA4, first half: OOTS-France reads a requester's key set as any correspondent
  # would, holding no session of this console. A route the operator's login
  # guarded would refuse the very component that has to read it.
  it 'answers a caller holding no session' do
    expect(response).to have_http_status(:ok)
    expect(published).to be_present
  end

  # RFC 7517 §4.2: what is published here authenticates a signature, and saying
  # `enc` would say the opposite of what the key is for.
  it 'declares the key as a signing one' do
    expect(published['use']).to eq('sig')
  end

  it 'publishes the curve the token is signed on, and no private member' do
    expect(published).to include('kty' => 'EC', 'crv' => 'P-256')
    expect(published.keys).not_to include(*PublicKeySet::SECRET_MEMBERS)
  end

  # Distinct from `/auth/cles_publiques`, which publishes what a service
  # provider encrypts a beneficiary token *for*. Two interfaces, two keys, and
  # a demonstration sharing one would prove nothing about either.
  it 'is not the key this deployment decrypts with' do
    signing = published

    get '/auth/cles_publiques'

    expect(response.parsed_body['keys'].first['kid']).not_to eq(signing['kid'])
  end
end
