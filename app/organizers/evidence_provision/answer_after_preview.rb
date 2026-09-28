module EvidenceProvision
  # Answers the second request of a preview later than it arrived: once the
  # user has decided (chapter 4.9 §3), or once T3 has run out on them (§2, step
  # 14).
  #
  # Nothing above it settles the exchange when the gateway refuses the answer,
  # as `IncomingMessage::Process` does on arrival: done here, then re-raised so
  # the job records it. The session no longer holds the row out of the T1
  # sweep, and what it kept of the user goes.
  class AnswerAfterPreview < ApplicationOrganizer
    organize RecallSecondRequest, Answer

    # What each failure is called, as `IncomingMessage::Process` calls it.
    REASONS = {
      Faraday::Error => :exchange_failed,
      EbmsError => :exchange_impossible,
      UnreadableMessageError => :unreadable,
      ConfigurationError => :invalid_configuration,
    }.freeze

    def call
      super
    rescue *REASONS.keys => e
      abandon(e, REASONS.find { |family, _| e.is_a?(family) }.last)
      raise
    end

    private

    def abandon(error, reason)
      context.preview_session&.conclude!
      exchange = context.exchange
      return if exchange.nil? || !exchange.incoming? || exchange.settled?

      exchange.failed!(code: nil, description: I18n.t('interactors.incoming_message.process.abandoned',
        reason: I18n.t("interactors.incoming_message.process.#{reason}"), error: error.message))
    end
  end
end
