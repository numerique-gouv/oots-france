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

  # `dense` pour une carte qui n'a rien à décrire entre son titre et ce qu'elle
  # énumère : l'air que le DSFR laisse sous le contenu y fait un trou.
  #
  # `clickable` étend le lien du titre au corps de la carte et lui donne la
  # flèche du DSFR. Ce qu'elle énumère doit alors vivre dans le pied, seul
  # endroit qui reste hors de cette étendue : un lien du corps passerait dessous
  # et cesserait d'être atteignable.
  def classes
    ['fr-card', 'fr-card--shadow', 'fr-mb-4w', ('card--dense' if @dense),
     (enlarged? ? 'fr-enlarge-link' : 'fr-card--no-arrow')]
  end

  def enlarged? = @clickable && @href.present?

  def title_tag(&) = content_tag("h#{@heading_level}", class: 'fr-card__title fr-mb-2w', &)

  # `hint` says what a shortened title leaves out.
  def heading = @href ? link_to(@title, @href, title: @hint) : @title
end
