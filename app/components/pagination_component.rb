# The DSFR pagination, which `dsfr-view-components` does not provide.
#
# `link` is given by the caller rather than built here: a component that knew
# how to write this application's URLs would be a controller.
class PaginationComponent < ViewComponent::Base
  # How many page numbers surround the current one before the list is elided.
  WINDOW = 2

  def initialize(current:, pages:, link:)
    @current = current
    @pages = pages
    @link = link
    super()
  end

  def render? = @pages > 1

  def numbers
    around = ((@current - WINDOW)..(@current + WINDOW)).to_a
    ([1, @pages] + around).uniq.grep(1..@pages).sort
  end

  def previous_page
    @current - 1 if @current > 1
  end

  def next_page
    @current + 1 if @current < @pages
  end

  def href(number) = @link.call(number)

  def current?(number) = number == @current

  # One place for the disabled state, which the two ends would otherwise spell
  # out twice — and which is where an accessibility fix would have to land.
  def edge_link(label, page, direction)
    classes = "fr-pagination__link fr-pagination__link--#{direction} fr-pagination__link--lg-label"

    return tag.span(label, class: classes, 'aria-disabled': true) if page.nil?

    link_to(label, href(page), class: classes)
  end
end
