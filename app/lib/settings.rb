# Single door onto the environment.
#
# One door and not several, because a variable read at its point of use is a
# variable nobody validates: an absent decryption key surfaces mid-request as a
# deserialisation error, an absent delay makes every request time out at once,
# and a URL captured when a file loads freezes for the life of the process.
# `verify!` fails at startup instead, on the whole of REQUIRED at once.
module Settings
  # Absent or blank, these leave the application unable to answer anything.
  REQUIRED = %w[
    IDENTIFIANT_FOURNISSEUR_FRANCAIS
    NOM_FOURNISSEUR_FRANCAIS
    URL_OOTS_FRANCE
    CLE_PRIVEE_JWK_EN_BASE64
    URL_BASE_DOMIBUS
    LOGIN_API_REST
    MOT_DE_PASSE_API_REST
    IDENTIFIANT_EXPEDITEUR_DOMIBUS
    TYPE_IDENTIFIANT_EXPEDITEUR_DOMIBUS
    SUFFIXE_IDENTIFIANTS_DOMIBUS
    LOGIN_NOTIFICATION_DOMIBUS
    MOT_DE_PASSE_NOTIFICATION_DOMIBUS
    ENVIRONNEMENT_SERVICES_COMMUNS
    PAYS_SERVICES_COMMUNS
    DUREE_CACHE_SERVICES_COMMUNS
    DELAI_MAX_SERVICES_COMMUNS
    CERTIFICATS_SERVICES_COMMUNS
    CLE_CHIFFREMENT_JOURNAL
    CLE_CHIFFREMENT_DETERMINISTE_JOURNAL
    SEL_DERIVATION_CLES_JOURNAL
    DUREE_RETENTION_JOURNAL_MOIS
    DELAI_RESERVATION_REMISE_MINUTES
  ].freeze

  # Those of REQUIRED that are read as numbers. Their format is verified at
  # startup like their presence: a delay of « bientôt » would otherwise pass
  # `verify!` and fail on the first request, which is the whole point of
  # checking here rather than at the point of use.
  NUMERIC = %w[
    DUREE_CACHE_SERVICES_COMMUNS DELAI_MAX_SERVICES_COMMUNS DUREE_RETENTION_JOURNAL_MOIS
    DELAI_RESERVATION_REMISE_MINUTES
  ].freeze

  # The two columns of the timeout table of chapter 4.4.3, asked of a deployment
  # that provides the dispositif and of no other: « The configuration shall
  # control whether timeout handling is provided and, if yes, the maximum
  # duration ». `Settings::Contract` composes them with REQUIRED and NUMERIC
  # only when the switch below leaves the dispositif on.
  TIMEOUTS = %w[DELAI_EXPIRATION_REQUETEUR_MINUTES DELAI_EXPIRATION_FOURNISSEUR_MINUTES].freeze

  # The other half of that sentence: whether timeout handling is provided at
  # all. Left empty the dispositif applies — a deployment saying nothing is one
  # that wants the behaviour the chapter describes — and only `false` takes it
  # away.
  TIMEOUT_SWITCH = 'AVEC_DELAI_EXPIRATION'.freeze

  # Article 17(4) of the implementing regulation, as a floor: a member state may
  # keep the exchange log longer, never less.
  LAWFUL_RETENTION_MONTHS = 12

  # The restricted role `web` and `worker` connect with. Optional, but paired.
  APPLICATION_DATABASE_ROLE = {
    username: 'UTILISATEUR_APPLICATIF_BASE_DE_DONNEES',
    password: 'MOT_DE_PASSE_APPLICATIF_BASE_DE_DONNEES',
  }.freeze

  # Optional, one per Common Service, keyed by the name `CommonServicesInstance` uses.
  COMMON_SERVICES_BASE_URLS = {
    'eb' => 'URL_BASE_EVIDENCE_BROKER',
    'dsd' => 'URL_BASE_DATA_SERVICE_DIRECTORY',
  }.freeze

  class << self
    def verify! = Contract.new.verify!

    def evidence_request_enabled? = ENV['AVEC_REQUETE_PIECE_JUSTIFICATIVE'] == 'true'

    # Chapter 4.4.3 lets a deployment provide no timeout handling at all, and
    # the two conditionals it writes — one per role — then have a false
    # antecedent: the sweep gives no exchange up and France answers the evidence
    # rather than `EDM:ERR:0005`. Which is the behaviour of an absent timeout,
    # not of an infinite one.
    def timeout_enabled? = timeout_switch != 'false'

    def french_provider_identity
      { id: required('IDENTIFIANT_FOURNISSEUR_FRANCAIS'), name: required('NOM_FOURNISSEUR_FRANCAIS') }
    end

    def private_key_jwk = JSON.parse(Base64.decode64(required('CLE_PRIVEE_JWK_EN_BASE64')))

    def evidence_requesters_data = JSON.parse(required('DONNEES_REQUETEURS'))

    # `acc` or `prod`, and the country whose NAPTR record names the instance to
    # query: chapter 3.4 lets a member state run its own.
    def common_services_environment = required('ENVIRONNEMENT_SERVICES_COMMUNS')

    def common_services_country_code = required('PAYS_SERVICES_COMMUNS')

    def common_services_cache_duration = whole('DUREE_CACHE_SERVICES_COMMUNS').seconds

    def common_services_timeout = whole('DELAI_MAX_SERVICES_COMMUNS').to_f / 1000

    def common_services_certificates = required('CERTIFICATS_SERVICES_COMMUNS')

    # Chapter 3.4 publishes the address of an instance as a NAPTR record, which
    # a deployment answering elsewhere — a caching proxy — has no way of being
    # named by. Set, this address is that instance; left empty, the record
    # decides, which is what every configuration here does.
    def common_services_base_url(service) = ENV.fetch(COMMON_SERVICES_BASE_URLS.fetch(service), nil).presence

    # Read without raising, unlike everything else here: this one is read while
    # the framework boots, and `rails db:test:prepare` or the task that renders
    # the specimen messages boot it without ever touching the log. REQUIRED
    # remains the guard — `config.ru` refuses to serve without the three.
    def audit_trail_encryption
      {
        primary_key: optional('CLE_CHIFFREMENT_JOURNAL'),
        deterministic_key: optional('CLE_CHIFFREMENT_DETERMINISTE_JOURNAL'),
        key_derivation_salt: optional('SEL_DERIVATION_CLES_JOURNAL'),
      }
    end

    # Article 17(4) of the implementing regulation sets twelve months, and says
    # so as a floor: a member state may keep them longer, hence a setting.
    def audit_trail_retention = whole('DUREE_RETENTION_JOURNAL_MOIS').months

    # The two columns of the timeout table of chapter 4.4.3, « ER side » and
    # « EP side », in the unit the chapter asks for: « all timeout intervals
    # within the system should be expressed in minutes ». The first must exceed
    # the second, which `Settings::Contract` refuses to start without.
    def requester_timeout = whole('DELAI_EXPIRATION_REQUETEUR_MINUTES').minutes

    def provider_timeout = whole('DELAI_EXPIRATION_FOURNISSEUR_MINUTES').minutes

    # How long `Exchange#claim_delivery!` holds a handover under way. Not a
    # timeout of chapter 4.4.3 but a guard against two workers handing the same
    # evidence over, so it is configured and read whether or not the dispositif
    # applies — and the method it serves says what the value arbitrates.
    def delivery_lease = whole('DELAI_RESERVATION_REMISE_MINUTES').minutes

    # Both or neither. Left empty, the two say « this deployment does not want
    # the dispositif », and everything runs as the owner of the tables, under
    # `AuditEvent#readonly?` alone. One alone says nothing of the kind — it is a
    # typo or a secret lost in a rotation — so the second read is `required`,
    # which names the one that is missing: answering `nil` would disarm the
    # engine-level guarantee on the exchange log without a word.
    def application_database_role
      return nil if APPLICATION_DATABASE_ROLE.each_value.none? { |name| optional(name) }

      APPLICATION_DATABASE_ROLE.transform_values { |name| required(name) }
    end

    def domibus_base_url = required('URL_BASE_DOMIBUS')

    def domibus_credentials
      { login: required('LOGIN_API_REST'), password: required('MOT_DE_PASSE_API_REST') }
    end

    # The credentials Domibus puts on the calls it makes *to us*, configured on
    # the gateway under `wsplugin.push.auth.*`. Distinct from the ones above,
    # which are ours for calling it: the two directions authenticate separately.
    def gateway_notification_credentials
      {
        login: required('LOGIN_NOTIFICATION_DOMIBUS'),
        password: required('MOT_DE_PASSE_NOTIFICATION_DOMIBUS'),
      }
    end

    def domibus_sender
      { id: required('IDENTIFIANT_EXPEDITEUR_DOMIBUS'), type_id: required('TYPE_IDENTIFIANT_EXPEDITEUR_DOMIBUS') }
    end

    def identifier_suffix = required('SUFFIXE_IDENTIFIANTS_DOMIBUS')

    private

    def whole?(value) = Integer(value, exception: false)&.positive? || false

    def whole(name)
      value = required(name)
      return Integer(value) if whole?(value)

      raise ConfigurationError,
        I18n.t('lib.settings.not_whole', names: I18n.t('lib.settings.not_whole_entry', name:, value:))
    end

    # Like `whole`, and for its reason: a value this cannot read is refused
    # where it is read rather than coalesced into one of the two answers. It
    # matters more here than anywhere else — `Settings::Contract` refuses the
    # same value at startup, but `config.ru` runs that check and the worker
    # never loads it, so the sweep and the answer would both read a malformed
    # switch that nothing had ever looked at.
    #
    # The value is compared unstripped on purpose: `timeout_enabled?` reads
    # « ` false` » as anything but `false`, so accepting it here would apply the
    # opposite of what the deployment wrote.
    def timeout_switch
      value = optional(TIMEOUT_SWITCH)
      return value if value.nil? || value.in?(%w[true false])

      raise ConfigurationError,
        I18n.t('lib.settings.not_boolean', name: TIMEOUT_SWITCH, value:)
    end

    def optional(name) = ENV.fetch(name, nil).presence

    def required(name)
      value = ENV.fetch(name, nil)
      return value if present?(value)

      raise ConfigurationError,
        I18n.t('lib.settings.required', name:)
    end

    def present?(value) = value.is_a?(String) && !value.strip.empty?
  end
end
