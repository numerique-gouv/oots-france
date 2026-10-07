module EvidenceProvision
  # Turns away a request whose header names no exchange to answer under —
  # `RetrievedMessageParser#identified?` says which.
  #
  # A step of the chain and not of `IncomingMessage::OpenExchange`, which simply
  # opens nothing for such a request: the refusal is journalled after the
  # arrival, so that the arrival is read first and the refusal says what became
  # of it.
  #
  # Refused the way an action we cannot name is refused, so that
  # `IncomingMessage::Process` gives up on its own terms. No answer goes back:
  # chapter 4.7 has a response reuse the `ExchangeId` of its request, so there is
  # none to build a conformant one with. The journal is therefore the only place
  # the decision can be read afterwards, and the arrival alone would not say why
  # nothing followed it — the sweep that settles an exchange finds none to
  # settle, this one having no identifier.
  class RejectUnidentifiedRequest < ApplicationInteractor
    def call
      return if context.message.identified?

      reason = I18n.t('interactors.evidence_provision.reject_unidentified_request.unidentified')
      journal(reason)

      raise UnreadableMessageError, reason
    end

    private

    def journal(reason)
      audit_trail.request_refused(
        requester_id: readable { request.requester.id },
        procedure_code: readable { request.procedure_code },
        country_code: readable { request.requester.address.country },
        reason:,
      )
    end

    def request = context.message.body
  end
end
