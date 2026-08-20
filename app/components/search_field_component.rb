# A search box that narrows a listing already on the page, in the browser.
#
# It submits nothing: `filter.js` reads the `data-filter*` attributes and hides
# what does not match. Hence no `fr-search-bar`, which the DSFR builds around a
# submit button — one here would be a control that does nothing.
#
# The caller gives CSS selectors rather than the elements themselves: what is
# narrowed, what tallies it and what is said when nothing is left are three
# parts of a page, and a component that reached into them would have to know
# how that page is built.
class SearchFieldComponent < ViewComponent::Base
  def initialize(label:, id:, entries:, tally: nil, empty: nil)
    @label = label
    @id = id
    @entries = entries
    @tally = tally
    @empty = empty
    super()
  end

  attr_reader :label, :id

  # The label doubles as the placeholder: a field whose only label is that
  # placeholder has none left the moment someone types into it.
  def field
    tag.input(class: 'fr-input', type: 'search', id:, autocomplete: 'off', placeholder: label,
      data: { filter: @entries, filter_tally: @tally, filter_empty: @empty })
  end
end
