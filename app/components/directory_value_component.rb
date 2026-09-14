# The mark a wording wears when it was published by the central directories and
# not written here: the title a member state declared its procedure under, the
# name of a requirement, of an evidence provider, of an evidence type.
#
# The demonstration plays a portal, and a portal's own sentences and the words
# Brussels publishes read alike on a screen. The mark tells them apart, so that
# a reader knows which of them this deployment could reword and which it could
# not.
#
# It wraps what the caller renders rather than rendering the value itself, so a
# value with a reading of its own keeps it under the mark. Deciding which values
# deserve it is the caller's alone.
class DirectoryValueComponent < ViewComponent::Base
  # The language the directory published the wording in, where the caller knows
  # it: a passage in another language than the page's carries its own `lang`,
  # failing which a screen reader pronounces English as French (RGAA 8.7).
  def initialize(lang: nil)
    @lang = lang
    super()
  end

  attr_reader :lang

  def label = t('components.directory_value.label')
end
