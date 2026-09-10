# Hands the evidence back to the French service provider that asked for it.
#
# Sent as what it is — a PDF, with its own content type — and not wrapped in a
# JSON envelope: the receiver saves the body to a file, and anything else makes
# it unpack a serialised byte array first.
#
# The body carries the evidence and nothing else, so the two identifiers that
# say which exchange it answers travel in the query string. They are the pair
# chapter 4.4 §4.3.2 defines — an `ExchangeId`, which OOTS introduces « to
# correlate all messages belonging to a single Evidence Request-Response
# exchange », and a `ConversationId`, whose messages « MUST relate to that
# user » — and carrying them on this hop is what chapter 1 §7.9 asks of a
# national link, which « must include all data elements required for enabling
# logging for end-to-end correlation, tracking and tracing of data flows ». A
# service provider leading two users at once can place a delivery only if it
# receives them: without any, it holds bytes and no question they answer. They
# are spelled the way `GET /requete/:exchange_id` already answers them, so that a
# caller reads one vocabulary from this deployment and not two.
class EvidenceForwarder
  PATH = '/oots/document'.freeze

  def initialize(connection: nil)
    @connection = connection
  end

  def deliver(evidence, requester, exchange)
    connection.post("#{requester.url}#{PATH}", evidence, 'Content-Type' => Attachment::MIME_TYPE) do |request|
      request.params.update(echange: exchange.exchange_id, conversation: exchange.conversation_id)
    end
  end

  private

  def connection
    @connection ||= Faraday.new do |builder|
      builder.request :retry, max: 2, interval: 0.5, backoff_factor: 2
      builder.response :raise_error
      builder.adapter :net_http
    end
  end
end
