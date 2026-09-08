module EvidenceProvision
  # Turns away a request whose ebMS header malforms either identifier, before
  # anything is built on them.
  #
  # `OutgoingEnvelopeBuilder` reuses both identifiers of the request in the
  # envelope France signs, so a malformed one would go back out under our own
  # signature and break `R-EDM-ebMS-017` or `-037` on our side, where it broke
  # them on the correspondent's.
  #
  # Hence a step of its own, before the two refusals `ChooseAnswer` pronounces:
  # theirs becomes an error response, which the envelope would dress in the very
  # identifiers being refused. Nothing conformant can carry this refusal at all
  # — chapter 4.4 has every message of one exchange reuse its `ExchangeId`, so
  # an exception would repeat the invalid value, and a fresh one would name a
  # different exchange. So nothing goes back, and the journal is the only place
  # the decision can be read afterwards.
  class RejectMalformedIdentifiers < ApplicationInteractor
    # The two identifiers the ebMS header carries, each under the FATAL rule
    # that fixes its shape, and named as the rule's own context names it. Both
    # assertions are made of the document and of no party, so they bind whoever
    # emits — a value a correspondent chose is ours the moment we sign it again.
    #
    # Ordered as the header presents them, so a request malforming both is
    # refused on the conversation and a reader of the journal knows which.
    UUID_RULES = {
      conversation_id: { rule: 'R-EDM-ebMS-017', element: 'eb:ConversationId' },
      exchange_id: { rule: 'R-EDM-ebMS-037', element: 'ExchangeId' },
    }.freeze

    def call
      UUID_RULES.each do |name, rule|
        value = context.message.public_send(name)
        refuse(rule, value) unless value.to_s.match?(Exchange::UUID)
      end
    end

    private

    # Hung on the exchange `IncomingMessage::OpenExchange` has already opened, so
    # the refusal joins the arrival that `IncomingMessage::Process` journalled
    # before dispatching. The reason names the rule, as `error_sent` does for the
    # refusals that do go back.
    def refuse(rule, value)
      reason = I18n.t('interactors.evidence_provision.reject_malformed_identifiers.malformed_identifier',
        element: rule[:element], value:, rule: rule[:rule])

      exchange = Exchange.find_by(exchange_id: context.message.exchange_id, incoming: true)

      audit_trail.request_refused(
        requester_id: exchange&.evidence_requester_id, procedure_code: exchange&.procedure_code,
        country_code: exchange&.country_code, reason:, exchange:,
      )

      raise UnreadableMessageError.new(reason, detail: rule[:rule])
    end
  end
end
