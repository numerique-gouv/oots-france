require 'rails_helper'

RSpec.describe Settings do
  # Those read as numbers need one, the others take anything non-blank. The two
  # timeouts are added rather than indexed — they leave REQUIRED to a deployment
  # that provides the dispositif — and take the values of the table of chapter
  # 4.4.3: the contract refuses them equal, which one value for every number
  # would make them.
  def filled
    Settings::REQUIRED
      .index_with { |name| name.in?(Settings::NUMERIC) ? '1000' : 'valeur' }
      .merge('DELAI_EXPIRATION_REQUETEUR_MINUTES' => '6', 'DELAI_EXPIRATION_FOURNISSEUR_MINUTES' => '5')
  end

  # 1000 satisfies the numeric check for every other duration; retention is read
  # in months, and twelve is its floor rather than its value.
  def lawful = filled.merge('DUREE_RETENTION_JOURNAL_MOIS' => '12')

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

  describe 'the retention of the exchange log' do
    # Keeping it less than twelve months breaks article 17(4) as surely as not
    # keeping it, and the nightly purge would carry that out silently.
    it 'refuses a retention shorter than the twelve months the regulation imposes' do
      with_environment(lawful.merge('DUREE_RETENTION_JOURNAL_MOIS' => '6')) do
        expect { described_class.verify! }.to raise_error(ConfigurationError, /article 17\(4\)/)
      end
    end

    # The one condition a stray `>` in place of `>=` would flip.
    it 'accepts exactly the floor' do
      with_environment(lawful) do
        expect { described_class.verify! }.not_to raise_error
        expect(described_class.audit_trail_retention).to eq(Settings::LAWFUL_RETENTION_MONTHS.months)
      end
    end

    it 'accepts a longer one, the twelve months being a floor' do
      with_environment(lawful.merge('DUREE_RETENTION_JOURNAL_MOIS' => '24')) do
        expect { described_class.verify! }.not_to raise_error
        expect(described_class.audit_trail_retention).to eq(24.months)
      end
    end
  end

  # Chapter 4.4: the interval an Online Procedure Portal waits « shall be
  # configured to a value that exceeds the timeout interval of the Data
  # Service ». Set the other way round, this side gives up while the
  # correspondent may still answer.
  describe 'the two expiry intervals' do
    # The switch is posed rather than left absent: the two answer the same, and a
    # rule that only ever meets the absent one proves half of what it says.
    it 'refuses a requester interval shorter than the provider one' do
      inverted = { Settings::TIMEOUT_SWITCH => 'true',
                   'DELAI_EXPIRATION_REQUETEUR_MINUTES' => '2',
                   'DELAI_EXPIRATION_FOURNISSEUR_MINUTES' => '10' }

      with_environment(filled.merge(inverted)) do
        expect { described_class.verify! }.to raise_error(ConfigurationError, /chapitre 4\.4/)
      end
    end

    # The condition a stray `>=` in place of `>` would flip: equal leaves the
    # buffer the table spends on transport at zero.
    it 'refuses them equal' do
      with_environment(filled.merge('DELAI_EXPIRATION_FOURNISSEUR_MINUTES' => '6')) do
        expect { described_class.verify! }.to raise_error(ConfigurationError, /chapitre 4\.4/)
      end
    end

    it 'reads both in minutes' do
      with_environment(filled) do
        expect(described_class.requester_timeout).to eq(6.minutes)
        expect(described_class.provider_timeout).to eq(5.minutes)
      end
    end

    it 'asks for both while the dispositif applies' do
      with_environment(filled.merge('DELAI_EXPIRATION_REQUETEUR_MINUTES' => nil)) do
        expect { described_class.verify! }
          .to raise_error(ConfigurationError, /DELAI_EXPIRATION_REQUETEUR_MINUTES/)
      end
    end

    # The other half of what the dispositif composes: presence is asked above,
    # format here, and a different rule carries each.
    it 'refuses one that is not a number while the dispositif applies' do
      with_environment(filled.merge('DELAI_EXPIRATION_REQUETEUR_MINUTES' => 'bientôt')) do
        expect { described_class.verify! }
          .to raise_error(ConfigurationError, /DELAI_EXPIRATION_REQUETEUR_MINUTES \(« bientôt »\)/)
      end
    end
  end

  # Chapter 4.4.3 asks the configuration two questions, and this is the first:
  # « The configuration shall control whether timeout handling is provided and,
  # if yes, the maximum duration ».
  describe 'whether timeout handling is provided at all' do
    # A deployment that says nothing is one that wants the behaviour the chapter
    # describes; the switch exists for the deployment that says otherwise.
    it 'is provided when the switch is not set' do
      with_environment(Settings::TIMEOUT_SWITCH => nil) do
        expect(described_class).to be_timeout_enabled
      end
    end

    it 'is provided when the switch says so' do
      with_environment(Settings::TIMEOUT_SWITCH => 'true') do
        expect(described_class).to be_timeout_enabled
      end
    end

    # The shape a deployment actually produces: `.env.oots.template` and the CI
    # script both write the name with nothing after the `=`, where a spec is
    # tempted to test the absent key instead.
    it 'is provided when the switch is posed and left empty' do
      with_environment(Settings::TIMEOUT_SWITCH => '') do
        expect(described_class).to be_timeout_enabled
      end
    end

    it 'is taken away by an explicit false' do
      with_environment(Settings::TIMEOUT_SWITCH => 'false') do
        expect(described_class).not_to be_timeout_enabled
      end
    end

    # Refused where it is written rather than read as a silent yes: France would
    # answer `EDM:ERR:0005` to a correspondent while the deployment believed the
    # dispositif off, which is the opposite of what a control commands.
    it 'refuses a switch that is neither true nor false, naming it' do
      with_environment(filled.merge(Settings::TIMEOUT_SWITCH => '0')) do
        expect { described_class.verify! }
          .to raise_error(ConfigurationError, /AVEC_DELAI_EXPIRATION vaut « 0 »/)
      end
    end

    # The value is compared unstripped, and the padding is what makes the
    # difference: `timeout_enabled?` reads « ` false` » as anything but `false`,
    # so tolerating it here would apply the opposite of what was written.
    it 'refuses a switch padded with a space, which reads as the wrong answer' do
      with_environment(filled.merge(Settings::TIMEOUT_SWITCH => ' false')) do
        expect { described_class.verify! }.to raise_error(ConfigurationError, /AVEC_DELAI_EXPIRATION/)
      end
    end

    # The refusal belongs to the reader and not to the contract alone: only the
    # web process runs `verify!` (`config.ru`), where the sweep and the answer
    # both read the switch from the worker.
    it 'refuses it at the point of use too, without any contract having run' do
      with_environment(Settings::TIMEOUT_SWITCH => '0') do
        expect { described_class.timeout_enabled? }
          .to raise_error(ConfigurationError, /AVEC_DELAI_EXPIRATION vaut « 0 »/)
      end
    end

    # « and, if yes, the maximum duration »: no dispositif, no duration to ask
    # for, which is what keeps the two intervals out of REQUIRED.
    it 'starts with neither interval configured once the dispositif is off' do
      off = Settings::TIMEOUTS.index_with { nil }.merge(Settings::TIMEOUT_SWITCH => 'false')

      with_environment(filled.merge(off)) do
        expect { described_class.verify! }.not_to raise_error
      end
    end

    # Values a deployment stopped using rather than deleted: refusing to start
    # on two intervals nothing reads would make taking the dispositif away a
    # two-step edit, and the second step easy to forget. Both checks are named
    # — the order and the format — since a different rule carries each.
    it 'ignores residual intervals left in the wrong order' do
      residual = { Settings::TIMEOUT_SWITCH => 'false',
                   'DELAI_EXPIRATION_REQUETEUR_MINUTES' => '2',
                   'DELAI_EXPIRATION_FOURNISSEUR_MINUTES' => '10' }

      with_environment(filled.merge(residual)) do
        expect { described_class.verify! }.not_to raise_error
      end
    end

    it 'ignores a residual interval that is not even a number' do
      residual = { Settings::TIMEOUT_SWITCH => 'false',
                   'DELAI_EXPIRATION_REQUETEUR_MINUTES' => 'bientôt' }

      with_environment(filled.merge(residual)) do
        expect { described_class.verify! }.not_to raise_error
      end
    end
  end

  # Not a timeout of chapter 4.4.3 but a guard against two workers handing the
  # same evidence over, so a deployment configures it either way.
  describe 'the lease on a delivery under way' do
    it 'reads in minutes' do
      with_environment(filled.merge('DELAI_RESERVATION_REMISE_MINUTES' => '6')) do
        expect(described_class.delivery_lease).to eq(6.minutes)
      end
    end

    it 'is asked for even with the dispositif off' do
      off = { Settings::TIMEOUT_SWITCH => 'false', 'DELAI_RESERVATION_REMISE_MINUTES' => nil }

      with_environment(filled.merge(off)) do
        expect { described_class.verify! }
          .to raise_error(ConfigurationError, /DELAI_RESERVATION_REMISE_MINUTES/)
      end
    end
  end

  describe '.audit_trail_encryption' do
    # Read while the framework boots, so it cannot raise: `rails db:test:prepare`
    # and the task that renders the specimen messages both load the application
    # without ever reading the log, and neither carries the keys. `REQUIRED`
    # stays the guard — the three are listed there, so `config.ru` refuses to
    # serve without them.
    it 'reads the keys without raising when they are absent' do
      absent = %w[CLE_CHIFFREMENT_JOURNAL CLE_CHIFFREMENT_DETERMINISTE_JOURNAL SEL_DERIVATION_CLES_JOURNAL]
        .index_with { nil }

      with_environment(absent) do
        expect(described_class.audit_trail_encryption.values).to all(be_nil)
      end
    end

    it 'is guarded by REQUIRED rather than at the point of use' do
      expect(Settings::REQUIRED).to include(
        'CLE_CHIFFREMENT_JOURNAL', 'CLE_CHIFFREMENT_DETERMINISTE_JOURNAL', 'SEL_DERIVATION_CLES_JOURNAL',
      )
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

  describe '.application_database_role' do
    def unset = Settings::APPLICATION_DATABASE_ROLE.values.index_with(nil)

    it 'is nothing when neither variable is set, the dispositif being optional' do
      with_environment(unset) do
        expect(described_class.application_database_role).to be_nil
      end
    end

    it 'reads the name and the password together' do
      with_environment(unset.transform_values { 'oots_france_app' }) do
        expect(described_class.application_database_role)
          .to eq(username: 'oots_france_app', password: 'oots_france_app')
      end
    end

    # One of the two alone is a typo or a secret lost in a rotation, never a
    # choice. Read as « no role », it would leave `web` and `worker` connecting
    # as the owner and take the engine-level guarantee on the exchange log away
    # without a word — which is the failure the whole measure exists to prevent.
    Settings::APPLICATION_DATABASE_ROLE.each_value do |alone|
      it "refuses #{alone} filled in on its own" do
        with_environment(unset.merge(alone => 'seule')) do
          expect { described_class.application_database_role }.to raise_error(ConfigurationError, /BASE_DE_DONNEES/)
        end
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
