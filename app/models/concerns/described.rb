# Something the central directories name in several languages at once.
#
# Which one to show is a choice, and it is made here rather than in each view:
# the language the page is read in where the directory publishes it, then the
# other of the two this application is read in — English being the one every
# entry of the catalogue carries —, then the first the directory published,
# which is its own order and not chance. A name in a language the reader may
# not have still beats a blank cell.
module Described
  extend ActiveSupport::Concern

  def self.preferred_languages = I18n.locale == :en ? %w[EN FR] : %w[FR EN]

  def label(languages: Described.preferred_languages) = in_preferred_language(descriptions, languages)

  # The language the wording chosen is written in, so that a page rendering it
  # can declare it: a passage in another language than the page's carries its
  # own `lang`, failing which a screen reader pronounces English as French
  # (RGAA 8.7).
  def label_language(languages: Described.preferred_languages) = chosen_language_in(descriptions, languages)

  private

  def chosen_language_in(published, languages = Described.preferred_languages)
    (languages & published.keys).first || published.keys.first
  end

  def in_preferred_language(published, languages = Described.preferred_languages)
    published[chosen_language_in(published, languages)]
  end
end
