# Hands the evidence back to the French service provider that asked for it.
#
# Sent as what it is — a PDF, with its own content type — and not wrapped in a
# JSON envelope: the receiver saves the body to a file, and anything else makes
# it unpack a serialised byte array first.
class EvidenceForwarder
  def initialize(connection: nil)
    @connection = connection
  end

  def deliver(evidence, requester)
    connection.post("#{requester.url}/oots/document", evidence, 'Content-Type' => Attachment::MIME_TYPE)
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
