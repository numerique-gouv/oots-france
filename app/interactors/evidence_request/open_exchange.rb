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
        exchange_id: asked.uuid.next,
        conversation_id: asked.conversation_id.presence || asked.uuid.next,
        procedure_code: asked.procedure_code,
        country_code: asked.country_code,
        evidence_requester_id: asked.requester.id,
      }
    end
  end
end
