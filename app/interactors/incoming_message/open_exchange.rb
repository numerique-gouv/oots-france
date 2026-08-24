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

    def request? = context.message.action == EbmsAction::EXECUTE_QUERY_REQUEST

    def request = context.message.body

    def opened
      {
        incoming: true,
        conversation_id: context.message.conversation_id,
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
