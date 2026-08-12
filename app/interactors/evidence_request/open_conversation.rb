module EvidenceRequest
  # Records the exchange before anything is sent.
  #
  # Before, and not after: the answer can come back before the submission call
  # has even returned, and a conversation created afterwards would be a
  # conversation the notification cannot find.
  class OpenConversation < ApplicationInteractor
    def call
      context.conversation = Conversation.create!(
        conversation_id: context.uuid.next,
        procedure_code: context.procedure_code,
        country_code: context.country_code,
        evidence_requester_id: context.requester.id,
      )
    end
  end
end
