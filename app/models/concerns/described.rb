# Something the central directories name in several languages at once.
#
# Which one to show is a choice, and it is made here rather than in each view:
# French where the directory publishes it — most member states do not —, then
# English, which every entry of the catalogue carries, then the first the
# directory published, which is its own order and not chance. A name in a
# language the reader may not have still beats a blank cell.
module Described
  extend ActiveSupport::Concern

  PREFERRED_LANGUAGES = %w[FR EN].freeze

  def label = in_preferred_language(descriptions)

  private

  # The language the wording chosen is written in, so that a page rendering it
  # can declare it: a passage in another language than the page's carries its
  # own `lang`, failing which a screen reader pronounces English as French
  # (RGAA 8.7).
  def chosen_language_in(published) = (PREFERRED_LANGUAGES & published.keys).first || published.keys.first

  def in_preferred_language(published) = published[chosen_language_in(published)]
end
