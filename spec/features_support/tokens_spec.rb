require 'webmock/rspec'
require File.expand_path('../../features/support/fake_france_connect/identities', __dir__)
require File.expand_path('../../features/support/fake_france_connect/tokens', __dir__)

# `computeSubV1` of the FranceConnect sources, whose shape the end-to-end
# scenario reads off one token: what it cannot show there is that the pseudonym
# is the same twice and different per service provider without ever carrying
# the node's identifier.
RSpec.describe FakeFranceConnect::Tokens do
  subject(:tokens) do
    described_class.new(procedure_key_set_url: 'http://exemple.invalid/cles', secret: 'un-secret')
  end

  let(:identity) { FakeFranceConnect::Identities.find('dk-substantial') }
  let(:other) { FakeFranceConnect::Identities.find('dk-high') }

  describe '#subject_for' do
    it 'rend 64 caractères hexadécimaux suivis de v1' do
      expect(tokens.subject_for('une-demarche', identity)).to match(/\A\h{64}v1\z/)
    end

    it 'rend le même pseudonyme pour une même identité et un même client' do
      first = tokens.subject_for('une-demarche', identity)

      expect(tokens.subject_for('une-demarche', identity)).to eq(first)
    end

    it 'rend un pseudonyme différent à un autre client' do
      expect(tokens.subject_for('une-demarche', identity)).not_to eq(tokens.subject_for('une-autre', identity))
    end

    it 'rend un pseudonyme différent à une autre identité' do
      expect(tokens.subject_for('une-demarche', identity)).not_to eq(tokens.subject_for('une-demarche', other))
    end

    # The `XX/YY/…` identifier the node yields never leaves the fake: it is
    # hashed into the pseudonym and appears nowhere in it.
    it 'ne laisse rien paraître de l\'identifiant eIDAS' do
      expect(tokens.subject_for('une-demarche', identity)).not_to include(identity.eidas_identifier)
      expect(tokens.subject_for('une-demarche', identity)).not_to include('/')
    end

    it 'sépare deux déploiements par leur secret' do
      elsewhere = described_class.new(procedure_key_set_url: 'http://exemple.invalid/cles', secret: 'un-autre')

      expect(tokens.subject_for('une-demarche', identity)).not_to eq(elsewhere.subject_for('une-demarche', identity))
    end
  end

  # The end-to-end scenario always meets an `RSA-OAEP-256` key, the one
  # `scripts/ci/prepare_environment.sh` generates: what a published key that
  # says something else does is only visible here.
  describe '#seal' do
    let(:rsa) { OpenSSL::PKey::RSA.generate(2048) }
    let(:published) { JWT::JWK.new(rsa).export.transform_keys(&:to_s) }

    def publishing(keys)
      stub_request(:get, 'http://exemple.invalid/cles').to_return(body: JSON.generate(keys: keys))
    end

    it 'chiffre pour la clé lue sur la route, avec l\'alg qu\'elle déclare' do
      publishing([published.merge('alg' => 'RSA-OAEP-256')])

      inner = JWE.decrypt(tokens.seal('sub' => 'un-pseudonyme'), rsa)

      expect(JWT.decode(inner, nil, false).first).to eq('sub' => 'un-pseudonyme')
    end

    it 'refuse ECDH-ES en nommant le gem qui ne sait pas le faire' do
      publishing([published.merge('alg' => 'ECDH-ES')])

      expect { tokens.seal('sub' => 'un-pseudonyme') }
        .to raise_error(described_class::UnsupportedKeyManagement, /jwe 1\.1\.1/)
    end

    it 'refuse une clé qui ne déclare aucun alg, plutôt que d\'en choisir un' do
      publishing([published])

      expect { tokens.seal('sub' => 'un-pseudonyme') }.to raise_error(/sans alg/)
    end

    it 'refuse un jeu de clés publié mais vide' do
      publishing([])

      expect { tokens.seal('sub' => 'un-pseudonyme') }.to raise_error(/aucune clé/)
    end
  end

  describe '#rotate' do
    it 'publie la clé neuve sans retirer les précédentes' do
      before_rotation = tokens.kids
      tokens.rotate

      expect(tokens.kids).to include(*before_rotation)
      expect(tokens.kids.size).to eq(before_rotation.size + 1)
    end
  end
end
