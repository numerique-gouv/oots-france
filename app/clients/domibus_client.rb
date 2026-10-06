# Talks to the Domibus WS plugin.
#
# No SOAP client: a `POST` in `text/xml` with basic authentication is all the
# plugin asks for. No MTOM and no WS-Security either — the gateway signs and
# encrypts the AS4 exchange itself, with its own keystore and truststore.
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

  # What the gateway recorded of its attempts to deliver a message France
  # submitted. A message it does not know is answered with a SOAP fault, which
  # reaches the caller as a `Faraday::Error`. `role` names the side France stood
  # on, for a message whose identifier the gateway may hold twice.
  def message_errors(message_id, role: nil)
    request = GetMessageErrorsBuilder.new(message_id:, access_point_role: role)

    MessageErrorsParser.new(post_soap(request.operation, request.render))
  end

  # The gateway pushes nothing about a test message, so its verdict is read
  # here.
  def message_status(message_id, role:)
    request = GetStatusBuilder.new(message_id:, access_point_role: role).render

    MessageStatusParser.new(post_soap('getStatusWithAccessPointRole', request))
  end

  # The plugin's credentials and policy, shared with `DomibusPartiesClient`,
  # which reads the same gateway through its REST interface.
  def self.connection
    Faraday.new(url: Settings.domibus_base_url) do |builder|
      credentials = Settings.domibus_credentials
      builder.request :authorization, :basic, credentials[:login], credentials[:password]
      builder.request :retry, max: 2, interval: 0.5, backoff_factor: 2
      builder.response :raise_error
      builder.adapter :net_http
    end
  end

  private

  def post_soap(operation, body)
    connection.post("#{WS_PLUGIN_PATH}/#{operation}", body, 'Content-Type' => 'text/xml').body
  end

  # Lazily, so the base URL is read now and not when the file loads, which
  # would freeze it for the life of the process.
  def connection = @connection ||= self.class.connection
end
