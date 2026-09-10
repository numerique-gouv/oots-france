module IncomingMessage
  # The mirror of `EvidenceRequest::OpenExchange`: a request addressed to
  # France opens its own exchange, so that answering leaves a row where asking
  # does. Only a request does — a response or an error names an exchange France
  # opened itself.
  #
  # `IncomingMessage::Process` has already asked whether this request opened a
  # row before — by its `ExchangeId` on the 2.0 line, by its own identifier on
  # the 1.2 one — so what is left here is to create the row that is missing.
  # Adopting an existing one writes nothing to it, and
  # `EvidenceProvision::JournalAnswer` settles an exchange France received and no
  # other.
  class OpenExchange < ApplicationInteractor
    def call
      return unless request?

      refuse_unless_identified

      context.exchange ||= open
    end

    private

    # `find_or_create_by!` and not `create!`: the fallback sweep can bring back a
    # message the push notification already delivered, and the unique index would
    # make the second arrival raise instead of being recognised. On the 1.2 line
    # the identifier is ours to mint, so there is nothing to find under it — the
    # repeat was recognised by the request identifier before this ran.
    def open
      Exchange.find_or_create_by!(exchange_id: identifier) do |exchange|
        exchange.assign_attributes(opened)
      end
    end

    # The `ExchangeId` the header carries, or one France mints for itself: a 1.2
    # message has no such property, and chapter 4.4 gives an exchange an
    # identifier all the same — the console, the journal and the expiry sweep all
    # name it by that. Minted here and emitted nowhere: `R-EDM-ebMS-018` counts
    # two properties on that line, and a third would break it.
    def identifier = context.message.exchange_id.presence || uuid.next

    # `R-EDM-ebMS-019` requires the `ExchangeId` property — `-018` only counts
    # them — and the ebMS3 envelope requires the `eb:ConversationId` element,
    # `R-EDM-ebMS-017` fixing its shape alone. A request carrying neither names
    # nothing to open a row under.
    #
    # The property is asked of the 2.0 line and of it alone: `R-EDM-ebMS-037` and
    # `-038` are rules 2.0.1 carries and 1.2.5 does not, so a conformant 1.2
    # request has no `ExchangeId` to give and refusing it for that would turn
    # away every correspondent of that line. The conversation is required either
    # way, the ebMS3 envelope carrying it in both.
    #
    # Refused the way an action we cannot name is refused,
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
      return if identified?

      reason = I18n.t('interactors.incoming_message.open_exchange.unidentified')
      journal_refusal(reason)

      raise UnreadableMessageError, reason
    end

    def journal_refusal(reason)
      audit_trail.request_refused(
        requester_id: readable { request.requester.id },
        procedure_code: readable { request.procedure_code },
        country_code: readable { request.requester.address.country },
        reason:,
      )
    end

    def identified?
      return false if context.message.conversation_id.blank?

      context.message.exchange_id.present? || !context.message.specification.exchange_named_in_header?
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
        specification: context.message.specification,
        ebms_sent_at: readable { context.message.sent_at },
        **requested,
      }
    end

    # The request identifier is written on this side too, and not left to the
    # journal: on the 1.2 line it is the only thing that ties a message back to
    # this exchange — the second delivery of the same request, the answer France
    # never sent — the `ExchangeId` naming it locally and travelling nowhere.
    def requested
      {
        request_id: readable { request.request_id },
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
