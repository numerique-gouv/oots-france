# The jurisdictions an entry appears in, as a row of tags.
#
# A flex row that wraps and spaces, so that twenty countries read as a set
# rather than as a sentence — which a comma-separated line does not.
#
# `caption` says in what capacity they appear, above the row: a card that leads
# somewhere puts this list in its footer, where the reader has left the sentence
# that would otherwise have introduced it.
class CountryTagListComponent < ViewComponent::Base
  def initialize(codes:, names: {}, link: nil, caption: nil)
    @codes = codes.compact_blank.uniq.sort
    @names = names
    @link = link
    @caption = caption
    super()
  end

  attr_reader :caption

  def render? = @codes.any?

  def entries
    @codes.map { |code| CountryTagComponent.new(code:, name: @names[code], href: @link&.call(code)) }
  end
end
