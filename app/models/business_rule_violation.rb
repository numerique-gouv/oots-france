# A rule of chapter 4.6 that a received message breaks, and what the rule says.
#
# Read and recorded, never raised. The chapter assigns the duty of validating to
# nobody, and chapter 4.5.3 opens no error path from a portal back to a
# provider: a response turned away over one of these would lose an evidence a
# correspondent legitimately sent, and tell no one. The journal names the rule
# instead — `AuditTrail` composes them into the `detail` of the arrival's line,
# and docs/journal_des_echanges.md holds the reasoning.
BusinessRuleViolation = Data.define(:rule, :description) do
  # Named rather than left to `to_s`, which string interpolation and `Array#join`
  # would call on their own: this one reaches for a translation, and where that
  # happens should be visible at the call.
  def sentence = I18n.t('models.business_rule_violation.sentence', rule:, description:)
end
