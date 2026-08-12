require 'rails_helper'

RSpec.describe Settings do
  describe '.verify!' do
    it 'passes when every required variable is filled in' do
      with_environment(Settings::REQUIRED.index_with { 'valeur' }) do
        expect { described_class.verify! }.not_to raise_error
      end
    end

    it 'names every missing variable at once, rather than the first one' do
      with_environment(Settings::REQUIRED.index_with { 'valeur' }
                                         .merge('URL_OOTS_FRANCE' => nil, 'LOGIN_API_REST' => nil)) do
        expect { described_class.verify! }
          .to raise_error(ConfigurationError, /URL_OOTS_FRANCE, LOGIN_API_REST/)
      end
    end

    # A variable set to spaces is the failure mode a hand-edited `.env` really
    # produces, and it reaches much further than an absent one before failing.
    it 'treats a blank variable as missing' do
      with_environment(Settings::REQUIRED.index_with { 'valeur' }.merge('SUFFIXE_IDENTIFIANTS_DOMIBUS' => '   ')) do
        expect { described_class.verify! }.to raise_error(ConfigurationError, /SUFFIXE_IDENTIFIANTS_DOMIBUS/)
      end
    end
  end

  describe '.evidence_request_enabled?' do
    it 'is true only for the exact string "true"' do
      with_environment('AVEC_REQUETE_PIECE_JUSTIFICATIVE' => 'true') do
        expect(described_class).to be_evidence_request_enabled
      end
    end

    it 'is false for anything else, including "1"' do
      with_environment('AVEC_REQUETE_PIECE_JUSTIFICATIVE' => '1') do
        expect(described_class).not_to be_evidence_request_enabled
      end
    end

    it 'is false when unset' do
      with_environment('AVEC_REQUETE_PIECE_JUSTIFICATIVE' => nil) do
        expect(described_class).not_to be_evidence_request_enabled
      end
    end
  end

  describe '.private_key_jwk' do
    it 'decodes the base64-wrapped JWK' do
      jwk = { 'kty' => 'RSA', 'n' => 'abc', 'e' => 'AQAB' }

      with_environment('CLE_PRIVEE_JWK_EN_BASE64' => Base64.strict_encode64(jwk.to_json)) do
        expect(described_class.private_key_jwk).to eq(jwk)
      end
    end

    # Read through the accessor and nowhere else: an unset key discovered at
    # the point of use surfaces mid-request, as a deserialisation error nobody
    # can trace back to a missing variable.
    it 'raises a configuration error when unset' do
      with_environment('CLE_PRIVEE_JWK_EN_BASE64' => nil) do
        expect { described_class.private_key_jwk }
          .to raise_error(ConfigurationError, /CLE_PRIVEE_JWK_EN_BASE64/)
      end
    end
  end

  describe '.french_provider_identity' do
    it 'reads the SIRET and the name together' do
      with_environment('IDENTIFIANT_FOURNISSEUR_FRANCAIS' => '00000000000001',
        'NOM_FOURNISSEUR_FRANCAIS' => 'Direction interministérielle du numérique') do
        expect(described_class.french_provider_identity)
          .to eq(id: '00000000000001', name: 'Direction interministérielle du numérique')
      end
    end
  end

  describe '.domibus_base_url' do
    # Memoising this at load time would freeze it for the life of the
    # process, and no change of environment could be picked up without a
    # restart.
    it 'is read at each call, never memoised' do
      with_environment('URL_BASE_DOMIBUS' => 'http://premier:8080/domibus') do
        expect(described_class.domibus_base_url).to eq('http://premier:8080/domibus')
      end

      with_environment('URL_BASE_DOMIBUS' => 'http://second:8080/domibus') do
        expect(described_class.domibus_base_url).to eq('http://second:8080/domibus')
      end
    end
  end

  def with_environment(variables)
    anciennes = variables.keys.index_with { |name| ENV.fetch(name, nil) }
    variables.each { |name, value| ENV[name] = value }
    yield
  ensure
    anciennes.each { |name, value| ENV[name] = value }
  end
end
