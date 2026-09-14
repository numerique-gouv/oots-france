# One entry of a listing, full width.
#
# `dsfr-view-components` ships a card, but only in the shape that wraps the
# whole of it in a single link. A listing of this console puts several links in
# one card — a requirement, a procedure, a country —, so the `fr-card` markup
# is written out here, as the tables and the form already are.
#
# What a card carries beside its title comes as content; what it *lists* comes
# as the `list` slot, rendered in the DSFR footer under a rule of its own. The
# two are not the same thing to read: the first describes the entry, the second
# enumerates what hangs off it.
class CardComponent < ViewComponent::Base
  renders_one :list

  def initialize(title:, href: nil, heading_level: 2, hint: nil, dense: false, clickable: false)
    @title = title
    @href = href
    @heading_level = heading_level
    @hint = hint
    @dense = dense
    @clickable = clickable
    super()
  end

  # `dense` for a card with nothing to describe between its title and what it
  # lists: the room the DSFR leaves under the content reads as a hole.
  #
  # `clickable` stretches the title's link over the body of the card and gives
  # it the DSFR arrow. What the card lists must then live in the footer, the one
  # place left outside that reach: a link in the body would fall under it and
  # stop being reachable.
  def classes
    ['fr-card', 'fr-card--shadow', 'fr-mb-4w', ('card--dense' if @dense),
     (enlarged? ? 'fr-enlarge-link' : 'fr-card--no-arrow')]
  end

  def enlarged? = @clickable && @href.present?

  def title_tag(&) = content_tag("h#{@heading_level}", class: 'fr-card__title fr-mb-2w', &)

  # `hint` says what a shortened title leaves out.
  def heading = @href ? link_to(@title, @href, title: @hint) : @title
end
