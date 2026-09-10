# What `IncomingMessage::Process` settles before it dispatches: which exchange
# the arriving message belongs to. Every handler downstream reads it from its
# context rather than looking it up, so a spec driving one of them directly
# stands in for the caller — and does it the one way the caller does, so that a
# change to the correlation reaches these specs too.
module Correlation
  def correlated(message)
    Exchange.correlate(
      exchange_id: message.exchange_id,
      request_id: requested_identifier(message),
      conversation_id: (message.conversation_id unless message.action == EbmsAction::EXECUTE_QUERY_REQUEST),
    )
  end

  private

  # A body too malformed to read names no request — the case `Process` covers
  # with the same rescue.
  def requested_identifier(message)
    message.body.request_id
  rescue UnreadableMessageError
    nil
  end
end
