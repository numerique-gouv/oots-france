require 'rails_helper'

RSpec.describe ProConnectToken do
  subject!(:token) { described_class.new(client: ProConnectClient.new(instance: stub_pro_connect)) }

  def claims(**overrides) = pro_connect_id_token_claims(**overrides)

  describe '#id_token_claims' do
    it 'reads an ID Token signed in RS256 by a key ProConnect publishes' do
      expect(token.id_token_claims(signed_by_pro_connect(claims), nonce: 'le-nonce-de-depart'))
        .to include('sub' => ProConnectStubs::AGENT_SUB)
    end

    it 'reads an ID Token signed in ES256' do
      key = OpenSSL::PKey::EC.generate('prime256v1')
      stub_request(:get, "#{ProConnectStubs::ISSUER}/jwks").to_return(body: { keys: [JWT::JWK.new(key).export] }.to_json)

      expect(token.id_token_claims(signed_by_pro_connect(claims, key:, algorithm: 'ES256'), nonce: 'le-nonce-de-depart'))
        .to include('sub' => ProConnectStubs::AGENT_SUB)
    end

    it 'refuses HS256, whose key would be the shared client secret' do
      signed = signed_by_pro_connect(claims, key: ProConnectStubs::CLIENT_SECRET, algorithm: 'HS256')

      expect { token.id_token_claims(signed, nonce: 'le-nonce-de-depart') }.to raise_error(ProConnectError)
    end

    it 'refuses a token signed by a key ProConnect does not publish' do
      signed = signed_by_pro_connect(claims, key: OpenSSL::PKey::RSA.generate(2048))

      expect { token.id_token_claims(signed, nonce: 'le-nonce-de-depart') }.to raise_error(ProConnectError)
    end

    {
      'another issuer' => { iss: 'http://ailleurs.test' },
      'another audience' => { aud: 'un-autre-client' },
      'an expiry passed' => { exp: 1.minute.ago.to_i },
      'no expiry' => { exp: nil },
      'another nonce' => { nonce: 'un-autre-nonce' },
    }.each do |spoiled, overrides|
      it "refuses #{spoiled}" do
        signed = signed_by_pro_connect(claims(**overrides).compact)

        expect { token.id_token_claims(signed, nonce: 'le-nonce-de-depart') }.to raise_error(ProConnectError)
      end
    end
  end

  describe '#userinfo_claims' do
    it 'reads a JSON answer' do
      expect(token.userinfo_claims({ sub: 'x', email: 'a@b' }.to_json, 'application/json; charset=utf-8'))
        .to eq('sub' => 'x', 'email' => 'a@b')
    end

    it 'reads a signed JWT answer' do
      expect(token.userinfo_claims(signed_by_pro_connect({ 'sub' => 'x' }), 'application/jwt'))
        .to eq('sub' => 'x')
    end

    it 'refuses a JWT answer signed by a key ProConnect does not publish' do
      signed = signed_by_pro_connect({ 'sub' => 'x' }, key: OpenSSL::PKey::RSA.generate(2048))

      expect { token.userinfo_claims(signed, 'application/jwt') }.to raise_error(ProConnectError)
    end

    it 'refuses any other type' do
      expect { token.userinfo_claims('<html>', 'text/html') }.to raise_error(ProConnectError, %r{text/html})
    end

    it 'refuses a JSON answer that is not an object' do
      expect { token.userinfo_claims('[]', 'application/json') }.to raise_error(ProConnectError, /objet/)
    end
  end
end
