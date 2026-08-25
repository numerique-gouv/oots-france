module IncomingMessage
  # Fetches a message the gateway is holding and does with it what its ebMS
  # action calls for: answer a request addressed to France, or settle the
  # exchange a correspondent is answering.
  #
  # Dispatched here rather than organised, because only one handler applies.
  class Process < ApplicationInteractor
    HANDLERS = {
      EbmsAction::EXECUTE_QUERY_REQUEST => EvidenceProvision::AnswerRequest,
      EbmsAction::EXECUTE_QUERY_RESPONSE => SettleExchange,
      EbmsAction::EXCEPTION_RESPONSE => SettleExchange,
    }.freeze

    def call
      context.message = context.gateway.retrieve(context.message_id)

      # The handler is resolved before the message is journalled, and not after:
      # an action we cannot name is not an event we can record, and it is the
      # resolution that says so.
      chosen = handler
      record

      chosen.call!(context)
    rescue UnreadableMessageError => e
      give_up(e)
    # Settled first so no user is left waiting, re-raised so the failure stays
    # visible in what GoodJob records. Never retried — `retrieveMessage` has
    # erased the message already.
    rescue Faraday::Error => e
      abandon_exchange(e, :exchange_failed)
      raise
    # `EbmsError` drives a 422 back to the caller at fault, and no caller is on
    # this path to receive it. One subclass does reach here all the same:
    # `SettleExchange` asks the directory where to hand the evidence over,
    # and `EvidenceRequesterNotFound` is raised there whenever the directory no
    # longer holds the requester of the exchange. What is too wide is the family
    # caught for that one subclass. Stub, tracked as OOTS-110.
    rescue EbmsError => e
      abandon_exchange(e, :exchange_impossible)
      raise
    end

    private

    # Recorded before it is handled, so that a request too malformed to answer
    # — the one an auditor most needs to find — is journalled all the same.
    #
    # Two arrivals still leave no line: an unreadable SOAP envelope, and an ebMS
    # action we cannot name, which `handler` refuses just above. Neither can be
    # qualified as an event. Tracked as OOTS-99.
    def record
      context.audit_trail.message_received(message: context.message, message_id: context.message_id)
      OpenExchange.call!(context)
    end

    # `fetch` and not `[]`: an unknown action must raise. Returning nil leaves
    # no log, no answer and no trace of a message that did arrive.
    def handler
      HANDLERS.fetch(context.message.action) do
        raise UnreadableMessageError,
          I18n.t('interactors.incoming_message.process.unknown_action', action: context.message.action)
      end
    end

    def give_up(error)
      Rails.logger.error(
        I18n.t('interactors.incoming_message.process.unreadable_logged', id: context.message_id, error: error.message),
      )

      abandon_exchange(error, :unreadable)
    end

    # Reachable only once the message names its exchange. A retrieval that
    # fails outright leaves nothing to go on — the identifier the gateway gave
    # us is its own — which is why the periodic sweep exists.
    #
    # The reason travels as a symbol, `interactors.incoming_message.process`
    # holding what each one reads as.
    def abandon_exchange(error, reason)
      exchange = Exchange.find_by(exchange_id: context.message&.exchange_id)
      return if exchange.nil? || exchange.settled?

      exchange.failed!(code: nil, description: said(error, reason))
    end

    def said(error, reason)
      I18n.t('interactors.incoming_message.process.abandoned',
        reason: I18n.t("interactors.incoming_message.process.#{reason}"), error: error.message)
    end
  end
end
