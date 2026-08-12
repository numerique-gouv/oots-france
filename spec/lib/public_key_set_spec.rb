require 'rails_helper'

RSpec.describe PublicKeySet do
  subject(:key) { described_class.new(private_jwk).to_h[:keys].first }

  let(:rsa) { OpenSSL::PKey::RSA.generate(2048) }
  let(:private_jwk) { JWT::JWK.new(rsa).export(include_private: true).transform_keys(&:to_s) }

  # The whole point of subtracting rather than enumerating: nothing secret can
  # slip through because someone forgot to copy a member across.
  it 'publishes no private member' do
    expect(key.keys).not_to include(*described_class::SECRET_MEMBERS)
  end

  it 'publishes the members that make the key usable' do
    expect(key).to include('kty' => 'RSA', 'n' => private_jwk['n'], 'e' => private_jwk['e'])
  end

  it 'declares the key is for encryption' do
    expect(key['use']).to eq('enc')
  end

  describe 'the key identifier' do
    # RFC 7638 defines a thumbprint for every key type, where the MD5 of a
    # modulus only ever made sense for RSA.
    it 'is the RFC 7638 thumbprint' do
      expected = Base64.urlsafe_encode64(
        OpenSSL::Digest::SHA256.digest(
          JSON.generate('e' => private_jwk['e'], 'kty' => 'RSA', 'n' => private_jwk['n']),
        ),
        padding: false,
      )

      expect(key['kid']).to eq(expected)
    end

    it 'is stable across calls for the same key' do
      premier = described_class.new(private_jwk).to_h
      second = described_class.new(private_jwk.dup).to_h

      expect(premier).to eq(second)
    end

    it 'differs between two keys' do
      other = JWT::JWK.new(OpenSSL::PKey::RSA.generate(2048)).export(include_private: true).transform_keys(&:to_s)

      expect(described_class.new(other).to_h[:keys].first['kid']).not_to eq(key['kid'])
    end
  end

  # The route this replaces enumerated `{ kty, n, e }` — RSA members — for a key
  # that was an EC one, and raised while computing the identifier rather than
  # serving something incomplete. Subtraction is what makes the type irrelevant.
  describe 'an elliptic-curve key' do
    let(:private_jwk) do
      JWT::JWK.new(OpenSSL::PKey::EC.generate('prime256v1')).export(include_private: true).transform_keys(&:to_s)
    end

    it 'publishes it without failing' do
      expect(key).to include('kty' => 'EC', 'crv' => 'P-256')
    end

    it 'keeps its coordinates and drops its private scalar' do
      expect(key.keys).to include('x', 'y')
      expect(key.keys).not_to include('d')
    end

    it 'identifies it by the thumbprint defined for its type' do
      expect(key['kid']).to be_present
    end
  end

  it 'refuses a key type it cannot thumbprint, rather than inventing one' do
    expect { described_class.new('kty' => 'OKP', 'crv' => 'Ed25519', 'x' => 'abc').to_h }
      .to raise_error(ConfigurationError, /OKP/)
  end
end
