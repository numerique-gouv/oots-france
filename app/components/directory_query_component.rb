# What the page asked the directories, and the identifiers the answer turns on.
#
# It is what makes these pages a diagnostic tool rather than one more listing:
# an operator reads the answer above and the exact question below it. Folded
# away, though — one comes here to read what the directories hold, and only
# afterwards, when the answer surprises, to check what was asked for it.
class DirectoryQueryComponent < ViewComponent::Base
  # `embedded` for the one that closes a card's footer rather than a page: it
  # ranges itself on the entries above rather than standing apart from them.
  def initialize(query_id:, parameters: {}, identifiers: {}, embedded: false)
    @query_id = query_id
    @parameters = parameters.compact_blank
    @identifiers = identifiers.compact_blank
    @embedded = embedded
    super()
  end

  attr_reader :query_id, :parameters, :identifiers

  def classes = @embedded ? %w[card-list__query] : %w[fr-mt-10w]
end
