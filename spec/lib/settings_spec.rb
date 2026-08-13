require 'rails_helper'

RSpec.describe Settings do
  # Those read as numbers need one, the others take anything non-blank.
  def filled = Settings::REQUIRED.index_with { |name| name.in?(Settings::NUMERIC) ? '1000' : 'valeur' }

  describe '.verify!' do
    it 'passes when every required variable is filled in' do
      with_environment(filled) do
        expect { described_class.verify! }.not_to raise_error
      end
    end

    # Checked at startup like presence: read at the point of use instead, a
    # delay of « bientôt » would only fail on the first request. Both are named
    # here rather than derived from NUMERIC, so dropping one from it shows.
    %w[DELAI_MAX_SERVICES_COMMUNS DUREE_CACHE_SERVICES_COMMUNS].each do |name|
      it "refuses #{name} when it is not a whole number" do
        with_environment(filled.merge(name => 'bientôt')) do
          expect { described_class.verify! }
            .to raise_error(ConfigurationError, /#{name} \(« bientôt »\)/)
        end
      end
    end

    # A delay of minus one passes `Integer()` and would reach Faraday as it is.
    it 'refuses a duration that is a number but not a positive one' do
      with_environment(filled.merge('DELAI_MAX_SERVICES_COMMUNS' => '-1')) do
        expect { described_class.verify! }.to raise_error(ConfigurationError, /entiers positifs/)
      end
    end

    # Named at once, like the absent ones: correcting one to discover the next
    # on the following deployment is the cycle this check exists to spare.
    it 'names every malformed number at once, rather than the first' do
      wrong = { 'DELAI_MAX_SERVICES_COMMUNS' => 'bientôt', 'DUREE_CACHE_SERVICES_COMMUNS' => 'longtemps' }

      with_environment(filled.merge(wrong)) do
        expect { described_class.verify! }.to raise_error(ConfigurationError) do |erreur|
          expect(erreur.message).to include('DELAI_MAX_SERVICES_COMMUNS', 'DUREE_CACHE_SERVICES_COMMUNS')
        end
      end
    end

    it 'names every missing variable at once, rather than the first one' do
      with_environment(filled.merge('URL_OOTS_FRANCE' => nil, 'LOGIN_API_REST' => nil)) do
        expect { described_class.verify! }
          .to raise_error(ConfigurationError, /URL_OOTS_FRANCE, LOGIN_API_REST/)
      end
    end

    # A variable set to spaces is the failure mode a hand-edited `.env` really
    # produces, and it reaches much further than an absent one before failing.
    it 'treats a blank variable as missing' do
      with_environment(filled.merge('SUFFIXE_IDENTIFIANTS_DOMIBUS' => '   ')) do
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

  describe '.common_services_base_url' do
    it 'reads the variable belonging to the service asked for' do
      with_environment('URL_BASE_EVIDENCE_BROKER' => 'http://web:4001/eb',
        'URL_BASE_DATA_SERVICE_DIRECTORY' => 'http://web:4001/dsd') do
        expect(described_class.common_services_base_url('dsd')).to eq('http://web:4001/dsd')
      end
    end

    # Nil and not a configuration error: the NAPTR record is what names the
    # instance when nothing else does.
    it 'is nil when the variable is unset' do
      with_environment('URL_BASE_EVIDENCE_BROKER' => nil) do
        expect(described_class.common_services_base_url('eb')).to be_nil
      end
    end

    it 'is nil when the variable is blank' do
      with_environment('URL_BASE_EVIDENCE_BROKER' => '   ') do
        expect(described_class.common_services_base_url('eb')).to be_nil
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
