# What the page asked the directories, and the identifiers the answer turns on.
#
# It is what makes these pages a diagnostic tool rather than one more listing:
# an operator reads the answer above and the exact question below it. Folded
# away, though — one comes here to read what the directories hold, and only
# afterwards, when the answer surprises, to check what was asked for it.
class DirectoryQueryComponent < ViewComponent::Base
  # The three questions the console ever puts to a directory, named here so that
  # a page asks for one by name: a `queryId` is what a client sends on the wire,
  # and a template that spelled one out would be reading `app/clients/` to
  # render a heading.
  QUERIES = {
    requirements: EvidenceBrokerClient::REQUIREMENTS_QUERY,
    evidence_types: EvidenceBrokerClient::EVIDENCE_TYPES_QUERY,
    data_services: DataServiceDirectoryClient::DATA_SERVICES_QUERY,
  }.freeze

  # `embedded` for the one that closes a card's footer rather than a page: it
  # ranges itself on the entries above rather than standing apart from them.
  def initialize(query:, parameters: {}, identifiers: {}, embedded: false)
    @query_id = QUERIES.fetch(query)
    @parameters = parameters.compact_blank
    @identifiers = identifiers.compact_blank
    @embedded = embedded
    super()
  end

  attr_reader :query_id, :parameters, :identifiers

  def classes = @embedded ? %w[card-list__query] : %w[fr-mt-10w]
end
