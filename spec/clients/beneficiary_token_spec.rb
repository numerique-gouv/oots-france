require 'rails_helper'

RSpec.describe BeneficiaryToken do
  subject(:opener) { described_class.new(requester, key_fetcher: fetcher) }

  let(:requester) { build(:evidence_requester) }

  # Ours: opens the envelope.
  let(:decryption_key) { OpenSSL::PKey::RSA.generate(2048) }
  # The requester's: authenticates what is inside.
  let(:signing_key) { OpenSSL::PKey::EC.generate('prime256v1') }

  let(:fetcher) { instance_double(JwksFetcher, call: JWT::JWK::Set.new([JWT::JWK.new(signing_key).export])) }

  let(:claims) do
    { 'nomUsage' => 'Dupont', 'prenom' => 'Sophie', 'dateNaissance' => '1965-11-25',
      'exp' => 10.minutes.from_now.to_i }
  end

  before do
    allow(Settings).to receive(:private_key_jwk)
      .and_return(JWT::JWK.new(decryption_key).export(include_private: true).transform_keys(&:to_s))
  end

  it 'names the beneficiary the token carries' do
    expect(opener.beneficiary(token))
      .to have_attributes(family_name: 'Dupont', given_name: 'Sophie', date_of_birth: '1965-11-25')
  end

  # Both lists are fixed by the code. A token allowed to name the algorithms
  # used to open and to check it is an algorithm-confusion surface where the
  # attacker picks the ground.
  describe 'the algorithms it accepts' do
    it 'refuses a token encrypted under another key-management algorithm' do
      other = encrypt(sign(claims), alg: 'RSA-OAEP')

      expect { opener.beneficiary(other) }
        .to raise_error(InvalidTokenError, %r{RSA-OAEP/A256GCM.*attendu RSA-OAEP-256/A256GCM})
    end

    it 'refuses a token encrypted under another content-encryption algorithm' do
      other = encrypt(sign(claims), enc: 'A128GCM')

      expect { opener.beneficiary(other) }.to raise_error(InvalidTokenError, %r{RSA-OAEP-256/A128GCM})
    end

    # The classic algorithm-confusion move: swap the signature for one the
    # verifier is willing to check with a key it already has.
    it 'refuses a token signed under another algorithm' do
      unexpected = encrypt(JWT.encode(claims, 'secret partagé', 'HS256'))

      expect { opener.beneficiary(unexpected) }.to raise_error(InvalidTokenError)
    end

    it 'refuses a token with no signature at all' do
      expect { opener.beneficiary(encrypt(JWT.encode(claims, nil, 'none'))) }
        .to raise_error(InvalidTokenError)
    end
  end

  it 'refuses a token signed by a key the requester does not publish' do
    stranger = sign(claims, key: OpenSSL::PKey::EC.generate('prime256v1'))

    expect { opener.beneficiary(encrypt(stranger)) }.to raise_error(InvalidTokenError)
  end

  it 'refuses an expired token' do
    expect { opener.beneficiary(encrypt(sign(claims.merge('exp' => 1.minute.ago.to_i)))) }
      .to raise_error(InvalidTokenError)
  end

  it 'refuses a token encrypted for someone else' do
    for_a_stranger = JWE.encrypt(sign(claims), OpenSSL::PKey::RSA.generate(2048).public_key,
      alg: 'RSA-OAEP-256', enc: 'A256GCM')

    expect { opener.beneficiary(for_a_stranger) }.to raise_error(InvalidTokenError)
  end

  it 'refuses something that is not a token' do
    expect { opener.beneficiary('pas un jeton') }.to raise_error(InvalidTokenError)
  end

  # A compact JWE has five segments. Truncated, it fails inside the decryption
  # itself with `JWE::DecodeError` — a *sibling* of `JWE::InvalidData`, not a
  # subclass, so rescuing the latter alone let it escape as an unhandled 500.
  #
  # The header is kept intact on purpose: a token that fails the algorithm
  # check earlier never reaches the decryption, and would pass this example
  # without exercising anything.
  it 'refuses a truncated token, whose header alone would pass' do
    segments = token.split('.')
    truncated = segments.first(4).join('.')

    expect { opener.beneficiary(truncated) }.to raise_error(InvalidTokenError, /Jeton bénéficiaire invalide/)
  end

  # Required so the verifier knows which published key to check against, rather
  # than accepting a signature from any of them.
  it 'refuses a token that does not say which key signed it' do
    anonymous = JWT.encode(claims, signing_key, 'ES256')

    expect { opener.beneficiary(encrypt(anonymous)) }.to raise_error(InvalidTokenError, /kid/)
  end

  def token = encrypt(sign(claims))

  # The `kid` designates which of the published keys signed: the requester's
  # key set may hold several, and trying them in turn would accept a signature
  # from any of them.
  def sign(payload, key: signing_key)
    JWT.encode(payload, key, 'ES256', kid: JWT::JWK.new(key).export[:kid])
  end

  def encrypt(signed, alg: 'RSA-OAEP-256', enc: 'A256GCM')
    JWE.encrypt(signed, decryption_key.public_key, alg:, enc:)
  end
end
