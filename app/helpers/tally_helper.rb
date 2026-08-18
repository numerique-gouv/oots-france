# The plural forms of a count, as the server renders them, so that a tally
# rewritten in JavaScript has no French of its own to carry.
#
# `COUNT` stands where the number goes: the pluralisation is I18n's, done here,
# and the browser only substitutes a figure.
module TallyHelper
  COUNT = 'COUNT'.freeze

  def tally_forms(key)
    { 0 => t("#{key}.zero"), 1 => t("#{key}.one"), other: t("#{key}.other", count: COUNT) }.to_json
  end
end
