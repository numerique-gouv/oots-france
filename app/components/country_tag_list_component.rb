# The jurisdictions an entry appears in, as a row of tags.
#
# A flex row that wraps and spaces, so that twenty countries read as a set
# rather than as a sentence — which a comma-separated line does not.
class CountryTagListComponent < ViewComponent::Base
  def initialize(codes:, names: {}, link: nil)
    @codes = codes.compact_blank.uniq.sort
    @names = names
    @link = link
    super()
  end

  def render? = @codes.any?

  def entries
    @codes.map { |code| CountryTagComponent.new(code:, name: @names[code], href: @link&.call(code)) }
  end
end
