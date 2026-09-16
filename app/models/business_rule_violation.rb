# What a received message breaks, and what it says: a rule of chapter 4.6, or
# the chapter itself where no published assertion executes its sentence — the
# consistency of the two version announcements, which `RetrievedMessageParser`
# names under 4.7 §2.6.2.
#
# Read and recorded, never raised. Chapter 4.6 assigns the duty of validating to
# nobody, 4.7 §2.6.2 names no subject for the error it asks for, and chapter
# 4.5.3 opens no error path from a portal back to a provider: a response turned
# away over one of these would lose an evidence a correspondent legitimately
# sent, and tell no one. The journal names the rule instead — `AuditTrail`
# composes them into the `detail` of the arrival's line, and
# docs/journal_des_echanges.md holds the reasoning.
BusinessRuleViolation = Data.define(:rule, :description) do
  # Named rather than left to `to_s`, which string interpolation and `Array#join`
  # would call on their own: this one reaches for a translation, and where that
  # happens should be visible at the call.
  def sentence = I18n.t('models.business_rule_violation.sentence', rule:, description:)
end
