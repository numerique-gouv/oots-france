# Something the central directories name in several languages at once.
#
# Which one to show is a choice, and it is made here rather than in each view:
# French where the directory publishes it — most member states do not —, then
# English, which every entry of the catalogue carries, then whatever there is.
# A name in a language the reader may not have still beats a blank cell.
module Described
  extend ActiveSupport::Concern

  PREFERRED_LANGUAGES = %w[FR EN].freeze

  def label = in_preferred_language(descriptions)

  private

  def in_preferred_language(published)
    published.values_at(*PREFERRED_LANGUAGES).compact.first || published.values.first
  end
end
