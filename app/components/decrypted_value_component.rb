# The mark a value wears when the page could only show it by decrypting it: the
# subject of an evidence and the canonical key it is searched by, the two columns
# `AuditEvent` declares `encrypts`. Chapter 4.8 names *Evidence subject
# information* among what must be logged, and `docs/journal_des_echanges.md` says
# why those two are the only ones.
#
# Nothing else in the console carries personal data, so a reader has no reason to
# expect any among the twenty columns of an event: the open padlock is what tells
# them apart, and it says as much that the value was encrypted at rest as that it
# is no longer.
#
# It wraps what the caller renders rather than rendering the value itself, so
# that a column with a reading of its own keeps it under the mark. Deciding which
# values deserve the mark is the caller's alone.
class DecryptedValueComponent < ViewComponent::Base
  def label = t('components.decrypted_value.label')
end
