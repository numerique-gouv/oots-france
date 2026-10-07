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
  #
  # A request whose header names no exchange opens nothing, and
  # `EvidenceProvision::RejectUnidentifiedRequest` refuses it once its arrival
  # is journalled.
  class OpenExchange < ApplicationInteractor
    def call
      return unless request? && context.message.identified?

      context.exchange ||= open
      reopen_previewed(context.exchange)
    end

    private

    # Chapter 4.7 §2.5.2: on the 2.0 line the second request of a preview
    # reuses the `ExchangeId` of the first, whose answer left this row
    # `preview_required`, and opens it again under its own request identifier,
    # the one the answer echoes. The 1.2 line names no exchange: its second
    # request opens a row of its own, tied to the first by the address alone.
    def reopen_previewed(exchange)
      return unless exchange.incoming? && exchange.preview_required?

      exchange.reopen!(readable { request.request_id })
    end

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
  end
end
