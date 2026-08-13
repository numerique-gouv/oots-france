# Talks to the Domibus WS plugin.
#
# No SOAP client: a `POST` in `text/xml` with basic authentication is all the
# plugin asks for. No MTOM and no WS-Security either — the gateway signs and
# encrypts the AS4 exchange itself, with the keystores of its security profile.
class DomibusClient
  WS_PLUGIN_PATH = 'services/wsplugin'.freeze

  def initialize(connection: nil)
    @connection = connection
  end

  def submit(envelope) = SubmittedMessageParser.new(post_soap('submitMessage', envelope))

  def pending_messages(conversation_id: nil)
    request = ListPendingMessagesBuilder.new(conversation_id:).render

    PendingMessagesParser.new(post_soap('listPendingMessages', request))
  end

  # The PMode carries `retention_downloaded="0"`, so the gateway erases the
  # message as it answers: what comes back has to be dealt with there and then.
  def retrieve(message_id)
    request = RetrieveMessageBuilder.new(message_id:).render

    RetrievedMessageParser.new(post_soap('retrieveMessage', request))
  end

  private

  def post_soap(operation, body)
    connection.post("#{WS_PLUGIN_PATH}/#{operation}", body, 'Content-Type' => 'text/xml').body
  end

  # Lazily, so the base URL is read now and not when the file loads, which
  # would freeze it for the life of the process.
  def connection
    @connection ||= Faraday.new(url: Settings.domibus_base_url) do |builder|
      credentials = Settings.domibus_credentials
      builder.request :authorization, :basic, credentials[:login], credentials[:password]
      builder.request :retry, max: 2, interval: 0.5, backoff_factor: 2
      builder.response :raise_error
      builder.adapter :net_http
    end
  end
end
