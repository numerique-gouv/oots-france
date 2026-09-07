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
    { 'niveauGarantie' => 'Substantial', 'nomUsage' => 'Dupont', 'prenom' => 'Sophie',
      'dateNaissance' => '1965-11-25', 'exp' => 10.minutes.from_now.to_i }
  end

  before do
    allow(Settings).to receive(:private_key_jwk)
      .and_return(JWT::JWK.new(decryption_key).export(include_private: true).transform_keys(&:to_s))
  end

  it 'names the beneficiary the token carries' do
    expect(opener.beneficiary(token))
      .to have_attributes(family_name: 'Dupont', given_name: 'Sophie', date_of_birth: '1965-11-25')
  end

  # The level the portal obtained at the eIDAS authentication, carried word for
  # word: chapter 4.5.1 §3.6 makes the requester answerable for it matching what
  # actually took place, so nothing here supplies one.
  describe 'the level of assurance' do
    it 'carries the level the token declares' do
      expect(opener.beneficiary(token).level_of_assurance).to eq('Substantial')
    end

    it 'refuses a token that declares none' do
      expect { opener.beneficiary(encrypt(sign(claims.except('niveauGarantie')))) }
        .to raise_error(InvalidTokenError, /Le niveau de garantie/)
    end

    it 'refuses a level the code list does not publish, naming it and the three admitted' do
      expect { opener.beneficiary(encrypt(sign(claims.merge('niveauGarantie' => 'Medium')))) }
        .to raise_error(InvalidTokenError, /Medium.*Low, Substantial, High/)
    end
  end

  # Chapter 2.1 §2.4 leaves both optional, and FranceConnect+ publishes the sex
  # of a European user in the lower case of the eIDAS SAML attribute, where
  # `Gender-CodeList` codes it capitalised.
  describe 'the optional attributes' do
    it 'leaves both unset when the token carries neither' do
      expect(opener.beneficiary(token)).to have_attributes(gender: nil, place_of_birth: nil)
    end

    it 'carries the place of birth as it was written' do
      opened = opener.beneficiary(encrypt(sign(claims.merge('lieuNaissance' => 'Aarhus'))))

      expect(opened.place_of_birth).to eq('Aarhus')
    end

    it 'writes the sex in the vocabulary of the code list' do
      written = %w[male female unspecified].map do |announced|
        opener.beneficiary(encrypt(sign(claims.merge('sexe' => announced)))).gender
      end

      expect(written).to eq(%w[Male Female Unspecified])
    end

    # Refused rather than capitalised into a value the code list still would not
    # publish, and refused naming what the portal sent: `Other` in the message
    # would send whoever reads it looking for a value nobody wrote.
    it 'refuses a sex the code list does not publish, naming what was sent' do
      expect { opener.beneficiary(encrypt(sign(claims.merge('sexe' => 'other')))) }
        .to raise_error(InvalidTokenError, /other.*Male, Female, Unspecified, 0, 1, 2, 3, 4, 5, 6, 9/)
    end
  end

  # `R-EDM-REQ-C040`: the requester writes what it received, and a token whose
  # identifier could never travel is turned away here rather than in a message
  # the correspondent refuses.
  describe 'the eIDAS identifier' do
    it 'carries an identifier of the shape the rule imposes' do
      opened = opener.beneficiary(encrypt(sign(claims.merge('identifiantEidas' => 'ES/AT/02635542Y'))))

      expect(opened.eidas_identifier).to eq('ES/AT/02635542Y')
    end

    it 'refuses an identifier the rule would not admit' do
      expect { opener.beneficiary(encrypt(sign(claims.merge('identifiantEidas' => '02635542Y')))) }
        .to raise_error(InvalidTokenError, %r{PAYS/PAYS/IDENTIFIANT})
    end
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
