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
        Rails.logger.warn("Conversation inconnue : #{context.message.conversation_id}")
        return
      end

      context.conversation = conversation
      settle(conversation)
    end

    private

    def settle(conversation)
      case context.message.action
      when EbmsAction::EXECUTE_QUERY_RESPONSE then deliver(conversation)
      when EbmsAction::EXCEPTION_RESPONSE then record_error(conversation)
      end
    end

    def deliver(conversation)
      requester = context.requesters.find(conversation.evidence_requester_id)

      context.evidence_forwarder.deliver(context.message.evidence, requester)
      conversation.delivered!
    end

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
