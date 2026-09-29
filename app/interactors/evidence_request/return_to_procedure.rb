module EvidenceRequest
  # The user coming back through France's return address (chapter 4.9 §5):
  # journalled, and sent on to the page the portal named when it confirmed,
  # with the two identifiers of the exchange — chapter 1 §7.9 has the link back
  # « include all data elements required for enabling logging for end-to-end
  # correlation », in the words `POST /oots/document` already uses.
  class ReturnToProcedure < ApplicationInteractor
    def call
      exchange = context.exchange

      context.resume_address = resume_address(exchange)
      audit_trail.return_to_procedure(exchange:, location: context.location)
    end

    private

    # Appended to whatever query the portal's address already carries, rather
    # than concatenated onto it.
    def resume_address(exchange)
      address = URI.parse(exchange.resume_location)
      carried = URI.decode_www_form(address.query.to_s)
      address.query = URI.encode_www_form(
        [*carried, ['echange', exchange.exchange_id], ['conversation', exchange.conversation_id]],
      )

      address.to_s
    end
  end
end
