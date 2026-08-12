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
  ].freeze

  class << self
    def verify!
      missing = REQUIRED.reject { |name| present?(ENV.fetch(name, nil)) }
      return if missing.empty?

      raise ConfigurationError,
        "Variables d'environnement obligatoires absentes ou vides : #{missing.join(', ')}."
    end

    def evidence_request_enabled? = ENV['AVEC_REQUETE_PIECE_JUSTIFICATIVE'] == 'true'

    def french_provider_identity
      { id: required('IDENTIFIANT_FOURNISSEUR_FRANCAIS'), name: required('NOM_FOURNISSEUR_FRANCAIS') }
    end

    def private_key_jwk = JSON.parse(Base64.decode64(required('CLE_PRIVEE_JWK_EN_BASE64')))

    def common_services_data = JSON.parse(required('DONNEES_DEPOT_SERVICES_COMMUNS_LOCAL'))

    def evidence_requesters_data = JSON.parse(required('DONNEES_REQUETEURS'))

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

    def required(name)
      value = ENV.fetch(name, nil)
      return value if present?(value)

      raise ConfigurationError,
        "La variable d'environnement #{name} est obligatoire et ne peut pas être vide."
    end

    def present?(value) = value.is_a?(String) && !value.strip.empty?
  end
end
