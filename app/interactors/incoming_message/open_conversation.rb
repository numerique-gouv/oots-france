module IncomingMessage
  # The mirror of `EvidenceRequest::OpenConversation`: a request addressed to
  # France opens its own exchange, so that answering leaves a row where asking
  # does. Only a request does — a response or an error names an exchange France
  # opened itself.
  #
  # `find_or_create_by!` and not `create!`: the fallback sweep can bring back a
  # message the push notification already delivered, and the unique index would
  # make the second arrival raise instead of being recognised.
  class OpenConversation < ApplicationInteractor
    def call
      return unless request?

      # Cherché sur le sens autant que sur l'identifiant : celui-ci est repris
      # tel quel de l'en-tête ebMS du correspondant, à qui la France a fait
      # connaître les siens en requêtant. Sans le sens, une requête qui en
      # rejoue un adopterait l'échange sortant qu'il désigne, et la réponse
      # française le réglerait à la place de celle qu'il attend. L'index unique
      # fait alors lever plutôt qu'admettre.
      Conversation.find_or_create_by!(conversation_id: context.message.conversation_id,
        incoming: true) do |conversation|
        conversation.assign_attributes(opened)
      end
    end

    private

    def request? = context.message.action == EbmsAction::EXECUTE_QUERY_REQUEST

    def request = context.message.body

    def opened
      {
        procedure_code: readable { request.procedure_code },
        country_code: readable { request.requester.address.country },
        evidence_requester_id: readable { request.requester.id },
      }
    end

    # A body too malformed to read opens an exchange all the same: what it would
    # have named is simply absent, field by field, as it is in the journal.
    def readable
      yield
    rescue UnreadableMessageError
      nil
    end
  end
end
