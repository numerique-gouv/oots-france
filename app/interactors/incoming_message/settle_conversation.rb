module IncomingMessage
  # Records what a correspondent answered, on the conversation that asked. Kept
  # on the record and not held in memory: the process that receives the answer
  # is rarely the one that asked.
  class SettleConversation < ApplicationInteractor
    def call
      conversation = Conversation.find_by(conversation_id: context.message.conversation_id)

      # A conversation we never opened: logged and not raised, there being
      # nobody to report it to.
      if conversation.nil?
        Rails.logger.warn(I18n.t('interactors.incoming_message.settle_conversation.unknown',
          id: context.message.conversation_id))
        return
      end

      context.conversation = conversation
      settle(conversation) if processable?(conversation)
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
    # genuine answer of the conversation it still has to reach.
    def processable?(conversation)
      return refuse(conversation, :already_settled) if conversation.settled? && !conversation.presumed?
      return refuse(conversation, :foreign_request) unless conversation.answers?(context.message.body.request_id)

      true
    end

    # Journalled as well as logged: this deployment's own rule, written where
    # `error_sent` already applies it — a refusal whose reason is not recorded
    # cannot be answered for afterwards, and nothing else holds this one.
    def refuse(conversation, reason)
      Rails.logger.warn(
        I18n.t("interactors.incoming_message.settle_conversation.#{reason}",
          id: conversation.conversation_id),
      )
      context.audit_trail.response_refused(conversation:, reason: reason.to_s)

      false
    end

    def settle(conversation)
      case context.message.action
      when EbmsAction::EXECUTE_QUERY_RESPONSE then deliver(conversation)
      when EbmsAction::EXCEPTION_RESPONSE then record_error(conversation)
      end
    end

    # `processable?` decided on the exchange as it stood when the message
    # arrived, and that decision holds: the sweep may expire the row while the
    # evidence is being handed over, and `Conversation#settle` lets this answer
    # overrule the presumption it made.
    def deliver(conversation)
      requester = context.requesters.find(conversation.evidence_requester_id)

      context.evidence_forwarder.deliver(evidence, requester)
      conversation.delivered!

      context.audit_trail.evidence_delivered(conversation:, evidence:)
    end

    def evidence = context.message.evidence

    def record_error(conversation)
      error = context.message.body

      # An authorisation error naming a usable preview location asks for a
      # detour, not a failure. One naming nowhere usable is a failure like any
      # other — better than sending a user to a link we could not vet.
      if error.preview_required? && error.preview_location?
        conversation.preview_required!(error.preview_location)
      else
        conversation.failed!(code: error.code, description: error.description)
      end
    end
  end
end
