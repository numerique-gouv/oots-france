module IncomingMessage
  # Fetches a message the gateway is holding and does with it what its ebMS
  # action calls for: answer a request addressed to France, or settle the
  # conversation a correspondent is answering.
  #
  # Dispatched here rather than organised, because only one handler applies.
  class Process < ApplicationInteractor
    HANDLERS = {
      EbmsAction::EXECUTE_QUERY_REQUEST => EvidenceProvision::AnswerRequest,
      EbmsAction::EXECUTE_QUERY_RESPONSE => SettleConversation,
      EbmsAction::EXCEPTION_RESPONSE => SettleConversation,
    }.freeze

    def call
      context.message = context.gateway.retrieve(context.message_id)

      handler.call!(context)
    rescue UnreadableMessageError => e
      give_up(e)
    # Settled first so no user is left waiting, re-raised so the failure is
    # visible: France answering another member state opens no conversation of
    # its own, and a job GoodJob records as failed is then the only signal.
    # Never retried — `retrieveMessage` has erased the message already.
    rescue Faraday::Error => e
      abandon_conversation(e, "L'échange a échoué")
      raise
    # `EbmsError` drives a 422 back to the caller at fault, and no caller is on
    # this path to receive it. Every subclass is raised while serving that
    # caller's own request, so none can reach here: the net is empty. Stub 9 of
    # `docs/reste_à_faire.md`.
    rescue EbmsError => e
      abandon_conversation(e, 'Échange impossible à mener à son terme')
      raise
    end

    private

    # `fetch` and not `[]`: an unknown action must raise. Returning nil leaves
    # no log, no answer and no trace of a message that did arrive.
    def handler
      HANDLERS.fetch(context.message.action) do
        raise UnreadableMessageError, "Action ebMS inconnue : « #{context.message.action} »."
      end
    end

    def give_up(error)
      Rails.logger.error("Message illisible (#{context.message_id}) : #{error.message}")

      abandon_conversation(error, 'Message illisible')
    end

    # Reachable only once the message names its conversation. A retrieval that
    # fails outright leaves nothing to go on — the identifier the gateway gave
    # us is its own — which is why the periodic sweep exists.
    def abandon_conversation(error, reason)
      conversation = Conversation.find_by(conversation_id: context.message&.conversation_id)
      return if conversation.nil? || conversation.settled?

      conversation.failed!(code: nil, description: "#{reason} : #{error.message}")
    end
  end
end
