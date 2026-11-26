module EvidenceProvision
  # Turns away a request whose ebMS header leaves its answer without an address:
  # every answer copies back the request's `originalSender` and `finalRecipient`
  # swapped, value and `type` (`AnswerBuilder#envelope`), and an identity
  # missing either half routes nowhere.
  #
  # A step of its own beside `RejectMalformedIdentifiers`, and in the same
  # shape: an exception response would have to be addressed with the very value
  # missing, so nothing goes back and the journal is the only place the decision
  # can be read. The reason names no rule — `R-EDM-ebMS-018` to `-021` judge an
  # absent property or `type` and an empty `type`, none an empty value — so that
  # the four cases read alike.
  class RejectUnaddressableRequest < ApplicationInteractor
    # The answer's recipient first, so a request missing both is refused on one
    # named corner and a reader of the journal knows which.
    CORNERS = { original_sender: 'originalSender', final_recipient: 'finalRecipient' }.freeze

    def call
      CORNERS.each do |corner, property|
        identity = context.message.public_send(corner)
        refuse(I18n.t('interactors.evidence_provision.reject_unaddressable_request.missing_value', property:)) if identity.id.blank?
        refuse(I18n.t('interactors.evidence_provision.reject_unaddressable_request.missing_type', property:)) if identity.type_id.blank?
      end
    end

    private

    # Hung on the exchange `IncomingMessage::Process` correlated or opened, so
    # the refusal joins the arrival it journalled before dispatching.
    def refuse(reason)
      exchange = context.exchange

      audit_trail.request_refused(
        requester_id: exchange&.evidence_requester_id, procedure_code: exchange&.procedure_code,
        country_code: exchange&.country_code, reason:, exchange:,
      )

      raise UnreadableMessageError, reason
    end
  end
end
