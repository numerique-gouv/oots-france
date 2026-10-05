module IncomingMessage
  # Records what a correspondent answered, on the exchange that asked. Kept
  # on the record and not held in memory: the process that receives the answer
  # is rarely the one that asked.
  class SettleExchange < ApplicationInteractor
    def call
      exchange = context.exchange

      # An exchange we never opened: logged and not raised, there being
      # nobody to report it to. Named by the conversation, which every message
      # carries on both lines, where the `ExchangeId` belongs to one of them.
      if exchange.nil?
        Rails.logger.warn(I18n.t('interactors.incoming_message.settle_exchange.unknown',
          id: context.message.conversation_id))
        return
      end

      settle(exchange) if processable?(exchange)
    end

    private

    # Chapter 4.4: « An Online Procedure Portal MUST NOT process responses that
    # use request identifiers of previous requests to which it already received
    # a response. » Refused before the branch, so a duplicate is turned away
    # whether it carries evidence or an error.
    #
    # An exchange the sweep gave up on, or closed on its access point's refusal,
    # has received no response at all, so that rule does not reach it: this
    # answer is the first, however late, and settling it is what refutes the
    # presumption.
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
      audit_trail.response_refused(exchange:, reason: reason.to_s)

      false
    end

    def requesters = context.requesters ||= Directories::EvidenceRequesters.new

    def evidence_forwarder = context.evidence_forwarder ||= EvidenceForwarder.new

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
    #
    # A success carrying no evidence says that none matches. Chapter 4.9 §2,
    # step 4, has a provider answer so at once, « independent of the value of
    # the "PossibilityForPreview" flag », and chapter 4.10 §2.1 has the portal
    # tell the user: `unmatched`. After a confirmed preview, chapter 4.9 §1 has
    # the same empty list say the user used none of it: `declined`.
    def respond(exchange)
      body = context.message.body

      return exchange.deferred!(body.response_available_at) if body.unavailable?
      return settle_without_evidence(exchange) if context.message.reports_no_evidence?

      deliver(exchange)
    end

    def settle_without_evidence(exchange)
      exchange.preview_confirmed? ? exchange.declined! : exchange.unmatched!
    end

    # `processable?` decided on the exchange as it stood when the message
    # arrived, and that decision holds: the sweep may expire the row while the
    # evidence is being handed over, and `Exchange#fire` lets this answer
    # overrule the presumption it made.
    #
    # What it cannot do is hold across the handover, which is why
    # `claim_delivery!` guards it. Nothing gives that reservation back: a POST
    # that raises settles the exchange in `IncomingMessage::Process`, and
    # releasing after one that reached the requester would license a second.
    def deliver(exchange)
      return refuse(exchange, :already_delivering) unless exchange.claim_delivery!

      requester = requesters.find(exchange.evidence_requester_id)

      evidence_forwarder.deliver(evidence.content, requester, exchange)
      exchange.delivered!

      audit_trail.evidence_delivered(exchange:, evidence:)
    end

    # The part and not its bytes: the journal records the reference the response
    # made of it as well as what it held.
    def evidence = context.message.evidence

    def record_error(exchange)
      error = context.message.body

      if preview_asked?(exchange, error)
        exchange.preview_required!(error.preview_location, descriptions: error.preview_descriptions,
          method: error.preview_method)
      else
        exchange.failed!(code: error.code, description: error.description)
      end
    end

    # An authorisation error naming a usable preview location asks for a
    # detour, not a failure. One naming nowhere usable is a failure like any
    # other — better than sending a user to a link we could not vet. And one
    # answering the second request is a failure too: chapter 1 §7.3 has no
    # preview offered in the second flow, and the exchange ends there.
    def preview_asked?(exchange, error)
      error.preview_required? && error.preview_location? && !exchange.preview_confirmed?
    end
  end
end
