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

      # Sur le seul identifiant, sans le sens : le scénario de bout en bout
      # boucle sur une passerelle unique, où la France est ses deux
      # correspondants et où le même identifiant désigne légitimement les deux
      # côtés d'un échange. Ce qu'une requête rejouant un identifiant émis par
      # la France pourrait faire de mal est écarté au règlement, où c'est
      # l'écriture qui a lieu — ici, adopter une ligne existante n'en change
      # aucune, le bloc ne jouant qu'à la création.
      Conversation.find_or_create_by!(conversation_id: context.message.conversation_id) do |conversation|
        conversation.assign_attributes(opened)
      end
    end

    private

    def request? = context.message.action == EbmsAction::EXECUTE_QUERY_REQUEST

    def request = context.message.body

    def opened
      {
        incoming: true,
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
