# One of the pictograms the DSFR distributes, at the size the caller's
# stylesheet gives it.
#
# The file is rendered as an image rather than inlined: each carries its own
# `<symbol>` elements, its own `<use>` and its own palette, so a distribution
# that redraws one redraws it here too, and nothing of the artwork is copied
# into this repository.
#
# Always decorative. Every pictogram placed here stands beside the wording that
# names what it depicts — an identity, a document — so an alternative would have
# a screen reader say the same thing twice (RGAA 1.2).
class PictogramComponent < ViewComponent::Base
  DIRECTORY = 'artwork/pictograms'.freeze

  def initialize(name:)
    @name = name
    super()
  end

  def source = image_path("#{DIRECTORY}/#{@name}.svg")
end
