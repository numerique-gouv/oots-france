module Settings
  # What the environment must satisfy for the application to answer at all,
  # checked once at startup by `config.ru`.
  #
  # Separate from `Settings`, which reads: a reader answers a question, a
  # contract refuses. Every rule names all its offenders at once — correcting
  # one to discover the next on the following deployment is the round trip this
  # check exists to spare.
  class Contract
    def verify!
      reject_unless_present
      reject_unless_whole
      reject_unless_lawful_retention
      reject_unless_timeouts_ordered
      reject_unless_france_connect_algorithm
      reject_unless_demo_signing_curve
    end

    private

    def reject_unless_present
      missing = with_timeouts(REQUIRED).reject { |name| ENV.fetch(name, nil).to_s.strip.present? }
      return if missing.empty?

      refuse(I18n.t('lib.settings.missing', names: missing.join(', ')))
    end

    def reject_unless_whole
      wrong = with_timeouts(NUMERIC).reject { |name| whole(name)&.positive? }
      return if wrong.empty?

      refuse(I18n.t('lib.settings.not_whole', names: wrong.map { |name| offender(name) }.join(', ')))
    end

    # Keeping the log less than twelve months breaks the obligation as surely as
    # not keeping it, and the nightly purge would carry that out without a word.
    #
    # Runs after `reject_unless_whole`, which has already refused anything that
    # does not parse: `nil` here can only mean a variable dropped from NUMERIC —
    # which is why the guard tolerates it rather than comparing to it.
    def reject_unless_lawful_retention
      months = whole('DUREE_RETENTION_JOURNAL_MOIS')
      return if months.nil? || months >= LAWFUL_RETENTION_MONTHS

      refuse(I18n.t('lib.settings.retention_below_floor', months:, floor: LAWFUL_RETENTION_MONTHS))
    end

    # Chapter 4.4: « The timeout interval used by Online Procedure Portals shall
    # be configured to a value that exceeds the timeout interval of the Data
    # Service and also takes into account the time needed for transmission and
    # processing of the response including eDelivery. » Set the other way round,
    # this side gives up while the correspondent may still answer, and then
    # receives the answer to an exchange it has closed.
    #
    # After `reject_unless_whole` and for its reason: a `nil` here can only mean
    # a variable dropped from NUMERIC. Skipped altogether where the dispositif
    # is off — the order of two intervals nothing reads settles nothing, and
    # residual values a deployment stopped using would refuse to start on it.
    def reject_unless_timeouts_ordered
      return unless Settings.timeout_enabled?

      requester = whole('DELAI_EXPIRATION_REQUETEUR_MINUTES')
      provider = whole('DELAI_EXPIRATION_FOURNISSEUR_MINUTES')
      return if requester.nil? || provider.nil? || requester > provider

      refuse(I18n.t('lib.settings.timeouts_out_of_order', requester:, provider:))
    end

    # `FRANCE_CONNECT_KEY_ALGORITHMS` says which two are admitted, and why they
    # are refused here rather than at the exchange.
    #
    # After `reject_unless_present`, which has already refused an empty value:
    # what is left is a value decoding to no JWK at all, and a JWK declaring no
    # usable `alg`. A JWK carries none of its own accord, so the two refusals
    # are distinct — one names a value to rewrite, the other a member to add.
    def reject_unless_france_connect_algorithm
      key = france_connect_key
      return refuse(I18n.t('lib.settings.france_connect_key_unreadable')) if key.nil?

      algorithm = key['alg']
      return if algorithm.in?(FRANCE_CONNECT_KEY_ALGORITHMS)

      expected = FRANCE_CONNECT_KEY_ALGORITHMS.join(', ')
      return refuse(I18n.t('lib.settings.france_connect_algorithm_absent', expected:)) if algorithm.blank?

      refuse(I18n.t('lib.settings.france_connect_algorithm', algorithm:, expected:))
    end

    # Read here rather than through `Settings`, which raises what a contract
    # answers: a malformed value is an offence to name, not an exception to
    # propagate.
    # The key the demonstration procedure signs its beneficiary token with, and
    # the one algorithm `BeneficiaryToken::SIGNATURE` admits to open it.
    # Refused here for the reason the rule above is: published on any other
    # curve, the key fails at the first signature instead — with a user midway
    # through a request, and far from anything this deployment can read.
    def reject_unless_demo_signing_curve
      key = decoded_jwk('CLE_PRIVEE_JWK_SIGNATURE_DEMARCHE_EN_BASE64')
      return refuse(I18n.t('lib.settings.demo_signing_key_unreadable')) if key.nil?

      return if [key['kty'], key['crv']] == DEMO_SIGNING_CURVE

      refuse(I18n.t('lib.settings.demo_signing_curve',
        kty: key['kty'].presence || I18n.t('lib.settings.unnamed_member'),
        crv: key['crv'].presence || I18n.t('lib.settings.unnamed_member')))
    end

    def france_connect_key = decoded_jwk('CLE_PRIVEE_JWK_DEMARCHE_EN_BASE64')

    def decoded_jwk(name)
      key = JSON.parse(Base64.decode64(ENV.fetch(name, '')))
      key if key.is_a?(Hash)
    rescue JSON::ParserError
      nil
    end

    # Which set is mandatory is a question of the dispositif, as `TIMEOUTS` says.
    # Asking it is also what refuses an unreadable switch here: `timeout_enabled?`
    # raises on a value that is neither `true` nor `false`, so the first rule to
    # compose a set carries that refusal and `verify!` needs no rule of its own
    # — the reader defends itself in every process, which `config.ru` cannot,
    # running `verify!` in the web one alone.
    def with_timeouts(names) = Settings.timeout_enabled? ? names + TIMEOUTS : names

    def offender(name) = I18n.t('lib.settings.not_whole_entry', name:, value: ENV.fetch(name, nil))

    def whole(name) = Integer(ENV.fetch(name, nil), exception: false)

    def refuse(message) = raise(ConfigurationError, message)
  end
end
