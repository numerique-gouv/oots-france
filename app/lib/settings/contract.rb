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
    end

    private

    def reject_unless_present
      missing = REQUIRED.reject { |name| ENV.fetch(name, nil).to_s.strip.present? }
      return if missing.empty?

      refuse(I18n.t('lib.settings.missing', names: missing.join(', ')))
    end

    def reject_unless_whole
      wrong = NUMERIC.reject { |name| whole(name)&.positive? }
      return if wrong.empty?

      refuse(I18n.t('lib.settings.not_whole', names: wrong.map { |name| offender(name) }.join(', ')))
    end

    # Keeping the log less than twelve months breaks the obligation as surely as
    # not keeping it, and the nightly purge would carry that out without a word.
    #
    # Runs last of the three: `reject_unless_whole` has already refused anything
    # that does not parse, so `nil` here can only mean a variable dropped from
    # NUMERIC — which is why the guard tolerates it rather than comparing to it.
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
    # a variable dropped from NUMERIC.
    def reject_unless_timeouts_ordered
      requester = whole('DELAI_EXPIRATION_REQUETEUR_MINUTES')
      provider = whole('DELAI_EXPIRATION_FOURNISSEUR_MINUTES')
      return if requester.nil? || provider.nil? || requester > provider

      refuse(I18n.t('lib.settings.timeouts_out_of_order', requester:, provider:))
    end

    def offender(name) = I18n.t('lib.settings.not_whole_entry', name:, value: ENV.fetch(name, nil))

    def whole(name) = Integer(ENV.fetch(name, nil), exception: false)

    def refuse(message) = raise(ConfigurationError, message)
  end
end
