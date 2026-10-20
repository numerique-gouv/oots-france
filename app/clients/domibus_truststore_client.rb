# Reads the certificates of the truststore the gateway has loaded, through the
# REST resource `/ext/truststore/entries`, which Domibus answers in one list,
# unpaged (`TruststoreExtResource`, `5.2-JEE10`).
class DomibusTruststoreClient
  PATH = 'ext/truststore/entries'.freeze

  def initialize(connection: nil)
    @connection = connection
  end

  def entries
    read.map { |entry| TruststoreEntry.new(name: entry['name'], subject: entry['subject']) }
  rescue Faraday::UnauthorizedError, Faraday::ForbiddenError => e
    raise GatewayError.new(I18n.t('clients.domibus_truststore_client.refused', error: e.message), refused: true)
  rescue Faraday::Error, JSON::ParserError => e
    raise GatewayError.new(I18n.t('clients.domibus_truststore_client.unreachable', error: e.message), refused: false)
  end

  private

  def read
    list = JSON.parse(connection.get(PATH).body)
    raise JSON::ParserError, list.class.name unless list.is_a?(Array) && list.all?(Hash)

    list
  end

  def connection = @connection ||= DomibusClient.connection
end
