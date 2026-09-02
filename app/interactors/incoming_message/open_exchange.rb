module IncomingMessage
  # The mirror of `EvidenceRequest::OpenExchange`: a request addressed to
  # France opens its own exchange, so that answering leaves a row where asking
  # does. Only a request does — a response or an error names an exchange France
  # opened itself.
  #
  # `find_or_create_by!` and not `create!`: the fallback sweep can bring back a
  # message the push notification already delivered, and the unique index would
  # make the second arrival raise instead of being recognised.
  class OpenExchange < ApplicationInteractor
    def call
      return unless request?

      refuse_unless_identified

      # On the exchange identifier alone, without the direction: chapter 4.4
      # requires every message of one exchange to reuse it, and the end-to-end
      # scenario loops through a single gateway, where France is both its
      # correspondents and one identifier legitimately names both sides.
      #
      # Adopting an existing row writes nothing to it, the block running only on
      # creation, and `EvidenceProvision::AnswerRequest` settles an exchange
      # France received and no other.
      Exchange.find_or_create_by!(exchange_id: context.message.exchange_id) do |exchange|
        exchange.assign_attributes(opened)
      end
    end

    private

    # `R-EDM-ebMS-019` requires the `ExchangeId` property — `-018` only counts
    # them — and the ebMS3 envelope requires the `eb:ConversationId` element,
    # `R-EDM-ebMS-017` fixing its shape alone. A request carrying neither names
    # nothing to open a row under. Refused the way an action we cannot name is refused,
    # so that `IncomingMessage::Process` gives up on its own terms — the arrival
    # is already journalled by then — rather than letting the row's own
    # validation raise where nothing catches it.
    #
    # No answer goes back: chapter 4.7 has a response reuse the `ExchangeId` of
    # its request, so there is none to build a conformant one with. The journal
    # is therefore the only place the decision can be read afterwards, and the
    # arrival alone would not say why nothing followed it — the sweep that
    # settles an exchange finds none to settle, this one having no identifier.
    def refuse_unless_identified
      return if context.message.exchange_id.present? && context.message.conversation_id.present?

      reason = I18n.t('interactors.incoming_message.open_exchange.unidentified')
      journal_refusal(reason)

      raise UnreadableMessageError, reason
    end

    def journal_refusal(reason)
      context.audit_trail.request_refused(
        requester_id: readable { request.requester.id },
        procedure_code: readable { request.procedure_code },
        country_code: readable { request.requester.address.country },
        reason:,
      )
    end

    def request? = context.message.action == EbmsAction::EXECUTE_QUERY_REQUEST

    def request = context.message.body

    # `ebms_sent_at` is the stamp the sending gateway put on the message, which
    # `Exchange.expired` counts a received exchange's timeout from — see there
    # for why our own reception will not do. Written at the opening because the
    # message is gone by the time anything else could read it:
    # `retention_downloaded="0"` erases it on retrieval.
    def opened
      {
        incoming: true,
        conversation_id: context.message.conversation_id,
        ebms_sent_at: readable { context.message.sent_at },
        **requested,
      }
    end

    def requested
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
