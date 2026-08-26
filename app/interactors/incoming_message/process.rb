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
      context.message = fetched

      # The handler is resolved before the message is journalled, and not after:
      # the two are different events, and it is the resolution that tells them
      # apart.
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

    # Journalled here rather than in `give_up`, which catches the same exception
    # raised from anywhere: by the time a handler is running, the message has a
    # line already, and a second one would say an arrival was lost that was not.
    #
    # A `Faraday::Error` is deliberately not journalled: `retrieveMessage`
    # consumes a message when it succeeds, so a call that did not is one the
    # sweep can simply make again — `CollectPendingMessagesJob` collects
    # whatever the gateway still holds, and a message collected twice is not
    # there the second time. An answer that did arrive and could not be read is
    # the loss, that call having succeeded.
    def fetched
      context.gateway.retrieve(context.message_id)
    rescue UnreadableMessageError => e
      context.audit_trail.message_unreadable(message_id: context.message_id, reason: e.message)
      raise
    end

    # Recorded before it is handled, so that a request too malformed to answer
    # — the one an auditor most needs to find — is journalled all the same.
    def record
      context.audit_trail.message_received(message: context.message, message_id: context.message_id)
      OpenExchange.call!(context)
    end

    # `fetch` and not `[]`: an unknown action must raise. Returning nil leaves
    # no answer and no trace of what the message asked for.
    def handler
      HANDLERS.fetch(context.message.action) do
        context.audit_trail.message_unhandled(message: context.message, message_id: context.message_id)

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
