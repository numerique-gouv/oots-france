module EvidenceRequest
  # Records the exchange before anything is sent.
  #
  # Before, and not after: the answer can come back before the submission call
  # has even returned, and an exchange created afterwards would be an exchange
  # the notification cannot find.
  #
  # Chapter 4.4 lets either the Procedure Portal or the Intermediary Platform
  # assign the conversation identifier. The caller supplies it when it is
  # leading one user through several requests — that is what makes them one
  # session — and this side mints one when it does not.
  #
  # Everything the directories resolved is kept with it, in case a
  # correspondent asks for a preview: the second request of chapter 4.9 repeats
  # the first, and `RequestBasis` says why it is not resolved again.
  class OpenExchange < ApplicationInteractor
    def call
      context.exchange = Exchange.create!(**opened)
    end

    private

    # `context` is aliased rather than read six times: each `context.foo` counts
    # twice against `Metrics/AbcSize`.
    def opened
      asked = context

      {
        exchange_id: uuid.next,
        conversation_id: asked.conversation_id.presence || uuid.next,
        procedure_code: asked.procedure_code,
        country_code: asked.country_code,
        evidence_requester_id: asked.requester.id,
        request_basis: basis,
      }
    end

    def basis
      resolved = context

      RequestBasis.new(
        requirement: resolved.requirement, provider: resolved.provider, recipient: resolved.recipient,
        data_service: resolved.data_service, evidence_type: resolved.evidence_type,
        preview_possible: resolved.preview_possible,
      )
    end
  end
end
