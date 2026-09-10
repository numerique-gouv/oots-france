module IncomingMessage
  # Fetches a message the gateway is holding and does with it what its ebMS
  # action calls for: answer a request addressed to France, or settle the
  # exchange a correspondent is answering.
  #
  # Dispatched here rather than organised, because only one handler applies.
  class Process < ApplicationInteractor
    HANDLERS = {
      EbmsAction::EXECUTE_QUERY_REQUEST => EvidenceProvision::Answer,
      EbmsAction::EXECUTE_QUERY_RESPONSE => SettleExchange,
      EbmsAction::EXCEPTION_RESPONSE => SettleExchange,
    }.freeze

    def call
      handle
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
    # The worker refuses to start on a configuration it cannot satisfy, so this
    # is what is left: a variable that fails only when the path that reads it is
    # taken. Rescued on `call` rather than on one method, as
    # `EvidenceRequest::SendToGateway` does, because there is no one method to
    # rescue — any of the handlers can read the environment, and the message is
    # consumed before the first of them runs.
    #
    # What makes that width safe is the startup check itself, not
    # `abandon_exchange`: `JournalAnswer` records before it settles, so an
    # answer already submitted sits on an exchange still `pending` while
    # `Answered` reads `Settings.french_provider_identity`. Every variable read
    # past a real submission belongs to `REQUIRED`, which the worker now
    # refuses to start without — one read from outside it would settle in
    # failure an exchange the correspondent has been answered on.
    rescue ConfigurationError => e
      abandon_exchange(e, :invalid_configuration)
      raise
    end

    private

    # The handler is resolved before the message is journalled, and not after:
    # the two are different events, and it is the resolution that tells them
    # apart. The exchange comes before both, so that the arrival is journalled
    # on the one it belongs to.
    #
    # Apart from `call`, which is nothing but the five failures below: what each
    # of them settles is what this method got as far as.
    def handle
      context.message = fetched
      chosen = handler
      context.exchange = correlated
      record

      chosen.call!(context)
    end

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
      gateway.retrieve(context.message_id)
    rescue UnreadableMessageError => e
      audit_trail.message_unreadable(message_id: context.message_id, reason: e.message)
      raise
    end

    # Recorded before it is handled, so that a request too malformed to answer
    # — the one an auditor most needs to find — is journalled all the same.
    def record
      audit_trail.message_received(message: context.message, message_id: context.message_id)
      OpenExchange.call!(context)
    end

    # Resolved once, here, and read from the context by everything downstream:
    # `OpenExchange` asks whether this request has opened a row already,
    # `SettleExchange` and `EvidenceProvision::RejectMalformedIdentifiers` act on
    # the one they found, and `EvidenceProvision::JournalAnswer` settles it. Four
    # readings where there was one lookup written out four times — and, on the
    # 1.2 line, four chances to disagree about a correlation the `ExchangeId` no
    # longer settles on its own.
    #
    # The conversation is offered only to a message that settles an exchange:
    # `Exchange.correlate` falls back on it, and a request arriving opens an
    # exchange of its own rather than adopting one that is merely underway.
    def correlated
      Exchange.correlate(
        exchange_id: context.message.exchange_id,
        request_id: readable { context.message.body.request_id },
        conversation_id: (context.message.conversation_id unless request?),
      )
    end

    def request? = context.message.action == EbmsAction::EXECUTE_QUERY_REQUEST

    # A body too malformed to read names no request, and the correlation falls
    # through to what the header carries — which is the whole of RG15's last
    # case.
    def readable
      yield
    rescue UnreadableMessageError
      nil
    end

    # `fetch` and not `[]`: an unknown action must raise. Returning nil leaves
    # no answer and no trace of what the message asked for.
    def handler
      HANDLERS.fetch(context.message.action) do
        audit_trail.message_unhandled(message: context.message, message_id: context.message_id)

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

    # Reachable only once the message has been correlated. A retrieval that
    # fails outright leaves nothing to go on — the identifier the gateway gave
    # us is its own — which is why the periodic sweep exists.
    #
    # The reason travels as a symbol, `interactors.incoming_message.process`
    # holding what each one reads as.
    def abandon_exchange(error, reason)
      exchange = context.exchange
      return if exchange.nil? || exchange.settled?

      exchange.failed!(code: nil, description: said(error, reason))
    end

    def said(error, reason)
      I18n.t('interactors.incoming_message.process.abandoned',
        reason: I18n.t("interactors.incoming_message.process.#{reason}"), error: error.message)
    end
  end
end
