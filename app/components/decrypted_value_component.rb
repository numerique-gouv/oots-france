# The mark a value wears when the page could only show it by decrypting it: the
# subject of an evidence, the canonical key it is searched by, and the RegRep
# document itself, the three columns `AuditEvent` declares `encrypts`. Chapter
# 4.8 names *Evidence subject information* among what must be logged, and
# `docs/journal_des_echanges.md` says why those three are the only ones.
#
# Nothing else in the console carries personal data, so a reader has no reason to
# expect any among the other columns of an event: the open padlock is what tells
# them apart, and it says as much that the value was encrypted at rest as that it
# is no longer.
#
# It wraps what the caller renders rather than rendering the value itself, so
# that a column with a reading of its own keeps it under the mark. Deciding which
# values deserve the mark is the caller's alone.
class DecryptedValueComponent < ViewComponent::Base
  # A value that renders as a block cannot sit in the inline wrapper: `<span>`
  # takes phrasing content only, and a folded document is a `<div>`. It also
  # aligns to the top, the padlock belonging beside the first line of a box and
  # not halfway down it.
  def initialize(block: false)
    @block = block
    super()
  end

  def tag_name = @block ? :div : :span

  def modifier = ('decrypted-value--block' if @block)

  def label = t('components.decrypted_value.label')
end
