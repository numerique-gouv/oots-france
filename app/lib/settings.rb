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
  ].freeze

  # Those of REQUIRED that are read as numbers. Their format is verified at
  # startup like their presence: a delay of « bientôt » would otherwise pass
  # `verify!` and fail on the first request, which is the whole point of
  # checking here rather than at the point of use.
  NUMERIC = %w[DUREE_CACHE_SERVICES_COMMUNS DELAI_MAX_SERVICES_COMMUNS].freeze

  class << self
    def verify!
      missing = REQUIRED.reject { |name| present?(ENV.fetch(name, nil)) }
      unless missing.empty?
        raise ConfigurationError,
          "Variables d'environnement obligatoires absentes ou vides : #{missing.join(', ')}."
      end

      reject_unless_whole(NUMERIC.reject { |name| whole?(ENV.fetch(name, nil)) })
    end

    def evidence_request_enabled? = ENV['AVEC_REQUETE_PIECE_JUSTIFICATIVE'] == 'true'

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

    # Named at once, like the absent ones above: correcting one to discover the
    # next on the following deployment is the cycle that check exists to spare.
    def reject_unless_whole(wrong)
      return if wrong.empty?

      raise ConfigurationError,
        "Variables d'environnement devant être des nombres entiers positifs : " \
        "#{wrong.map { |name| "#{name} (« #{ENV.fetch(name, nil)} »)" }.join(', ')}."
    end

    def whole?(value) = Integer(value, exception: false)&.positive? || false

    def whole(name)
      value = required(name)
      reject_unless_whole([name]) unless whole?(value)

      Integer(value)
    end

    def required(name)
      value = ENV.fetch(name, nil)
      return value if present?(value)

      raise ConfigurationError,
        "La variable d'environnement #{name} est obligatoire et ne peut pas être vide."
    end

    def present?(value) = value.is_a?(String) && !value.strip.empty?
  end
end
