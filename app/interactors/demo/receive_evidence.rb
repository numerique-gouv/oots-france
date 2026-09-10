module Demo
  # What the demonstration procedure does with an evidence delivered to it: file
  # it on the request that asked for it, or refuse it.
  #
  # Chapter 4.4 §4.3.2 gives the two identifiers a delivery carries their jobs —
  # the `ExchangeId` ties together the messages of one exchange, the
  # `ConversationId` ties them to one authenticated user — and chapter 4.10 §4.1,
  # informative, says what becomes of a delivery matching neither: « In case this
  # value is not linked to any known current user and/or user session, the event
  # is logged for investigation. »
  #
  # The application log and not the exchange log of article 17: this is the
  # portal's own trace. OOTS-France has recorded the handover on its own side
  # already, and a portal writing into that log would be writing into someone
  # else's book.
  #
  # Refused rather than swallowed, so the refusal is legible from both ends:
  # `EvidenceForwarder` raises on the status, and the exchange is settled for it
  # where it was opened.
  class ReceiveEvidence < ApplicationInteractor
    def call
      request = Request.find_by(exchange_id:)

      return unplaceable unless request&.answers?(exchange_id, conversation_id)
      return empty if evidence.blank?

      request.receive_evidence!(evidence)
    end

    private

    def exchange_id = context.exchange_id.presence

    def conversation_id = context.conversation_id.presence

    def evidence = context.evidence

    def unplaceable
      Rails.logger.warn(I18n.t('interactors.demo.receive_evidence.unplaceable',
        exchange: named(exchange_id), conversation: named(conversation_id)))

      fail_with_error(:demo_unplaceable)
    end

    def empty
      Rails.logger.warn(I18n.t('interactors.demo.receive_evidence.empty', exchange: named(exchange_id)))

      fail_with_error(:demo_evidence_empty)
    end

    # A delivery naming nothing is exactly the one worth reading in the log, so
    # the line says « non fourni » rather than trailing off.
    def named(identifier) = identifier || I18n.t('interactors.demo.receive_evidence.unnamed')
  end
end
