# The evidence types France answers for as an Evidence Provider: the two it
# declares at the Evidence Broker of the acceptance environment, « FR - Test
# Evidence Type » and « FR - Test Evidence Type for abroad ». A request is
# served on its evidence type, whatever procedure it names — `R1` aside, which
# is deferred whatever the type (`ProcedureCode.deferred?`): a provider holds
# evidence of a type, and `EDM:ERR:0004` — « Object not found » (chapter 4.5.3)
# — is what any other type gets. Stub, tracked as OOTS-82.
#
# Compared on the country and the UUID that end the classification, the
# Semantic Repository publishing it under `sr.acc.oots.tech.ec.europa.eu` in
# acceptance and `sr.oots.tech.ec.europa.eu` in production.
module ServedEvidenceType
  CLASSIFICATIONS = %w[
    FR/869a6748-bfc5-4de6-a0b4-ec0420f6b6a4
    FR/9bc466ca-d785-4b20-a5e2-0da1c0b9e931
  ].freeze

  def self.served?(evidence_type)
    CLASSIFICATIONS.any? { |classification| evidence_type.id.to_s.end_with?("/#{classification}") }
  end
end
