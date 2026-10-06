# Reads the parties of the PMode the gateway has loaded, through the REST
# resource `/ext/party` that the Plugin User opens.
#
# The resource pages by offset — `pageStart` is the number of parties skipped,
# `pageSize` defaults to ten (`PartyFilterRequestDTO`, Domibus `5.2-JEE10`) —
# so the list is read page after page until one comes back short.
class DomibusPartiesClient
  PATH = 'ext/party'.freeze
  PAGE_SIZE = 100

  def initialize(connection: nil)
    @connection = connection
  end

  def parties
    read_all.map { |party| party_from(party) }
  rescue Faraday::UnauthorizedError, Faraday::ForbiddenError => e
    raise GatewayError.new(I18n.t('clients.domibus_parties_client.refused', error: e.message), refused: true)
  rescue Faraday::Error, JSON::ParserError => e
    raise GatewayError.new(I18n.t('clients.domibus_parties_client.unreachable', error: e.message), refused: false)
  end

  private

  def read_all
    parties = []

    loop do
      page = JSON.parse(connection.get(PATH, pageStart: parties.size, pageSize: PAGE_SIZE).body)
      raise JSON::ParserError, page.class.name unless page.is_a?(Array)

      parties.concat(page)

      return parties if page.size < PAGE_SIZE
    end
  end

  # A party may carry several identifiers; messages address it by the first,
  # as the console of the gateway does.
  def party_from(party)
    identifier = Array(party['identifiers']).first || {}

    PmodeParty.new(
      name: party['name'],
      identifier: identifier['partyId'],
      identifier_type: identifier.dig('partyIdType', 'value'),
      endpoint: party['endpoint'],
    )
  end

  def connection = @connection ||= DomibusClient.connection
end
