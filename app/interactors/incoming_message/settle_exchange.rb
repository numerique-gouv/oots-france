module IncomingMessage
  # Records what a correspondent answered, on the exchange that asked. Kept
  # on the record and not held in memory: the process that receives the answer
  # is rarely the one that asked.
  class SettleExchange < ApplicationInteractor
    def call
      exchange = Exchange.find_by(exchange_id: context.message.exchange_id)

      # An exchange we never opened: logged and not raised, there being
      # nobody to report it to.
      if exchange.nil?
        Rails.logger.warn(I18n.t('interactors.incoming_message.settle_exchange.unknown',
          id: context.message.exchange_id))
        return
      end

      context.exchange = exchange
      settle(exchange) if processable?(exchange)
    end

    private

    # Chapter 4.4: « An Online Procedure Portal MUST NOT process responses that
    # use request identifiers of previous requests to which it already received
    # a response. » Refused before the branch, so a duplicate is turned away
    # whether it carries evidence or an error.
    #
    # An exchange the sweep gave up on has received no response at all, so that
    # rule does not reach it: this answer is the first, however late, and
    # settling it is what refutes the presumption.
    #
    # Nothing is answered and nothing is settled: the TDD open no error path
    # from a portal back to a provider, and failing the exchange would rob the
    # genuine answer of the exchange it still has to reach.
    def processable?(exchange)
      return refuse(exchange, :already_settled) if exchange.settled? && !exchange.presumed?
      return refuse(exchange, :foreign_request) unless exchange.answers?(context.message.body.request_id)

      true
    end

    # Journalled as well as logged: this deployment's own rule, written where
    # `error_sent` already applies it — a refusal whose reason is not recorded
    # cannot be answered for afterwards, and nothing else holds this one.
    def refuse(exchange, reason)
      Rails.logger.warn(
        I18n.t("interactors.incoming_message.settle_exchange.#{reason}",
          id: exchange.exchange_id),
      )
      context.audit_trail.response_refused(exchange:, reason: reason.to_s)

      false
    end

    def settle(exchange)
      case context.message.action
      when EbmsAction::EXECUTE_QUERY_RESPONSE then respond(exchange)
      when EbmsAction::EXCEPTION_RESPONSE then record_error(exchange)
      end
    end

    # Chapter 4.5.2: a response whose status announces the evidence for later
    # carries none, and is not a failure. Read before the evidence — which is
    # exactly what a deferral has not — and before `claim_delivery!`, which
    # would reserve a handover nothing is going to make.
    def respond(exchange)
      body = context.message.body

      return exchange.deferred!(body.response_available_at) if body.unavailable?

      deliver(exchange)
    end

    # `processable?` decided on the exchange as it stood when the message
    # arrived, and that decision holds: the sweep may expire the row while the
    # evidence is being handed over, and `Exchange#settle` lets this answer
    # overrule the presumption it made.
    #
    # What it cannot do is hold across the handover, which is why
    # `claim_delivery!` guards it. Nothing gives that reservation back: a POST
    # that raises settles the exchange in `IncomingMessage::Process`, and
    # releasing after one that reached the requester would license a second.
    def deliver(exchange)
      return refuse(exchange, :already_delivering) unless exchange.claim_delivery!

      requester = context.requesters.find(exchange.evidence_requester_id)

      context.evidence_forwarder.deliver(evidence.content, requester)
      exchange.delivered!

      context.audit_trail.evidence_delivered(exchange:, evidence:)
    end

    # The part and not its bytes: the journal records the reference the response
    # made of it as well as what it held.
    def evidence = context.message.evidence

    def record_error(exchange)
      error = context.message.body

      # An authorisation error naming a usable preview location asks for a
      # detour, not a failure. One naming nowhere usable is a failure like any
      # other — better than sending a user to a link we could not vet.
      if error.preview_required? && error.preview_location?
        exchange.preview_required!(error.preview_location)
      else
        exchange.failed!(code: error.code, description: error.description)
      end
    end
  end
end
