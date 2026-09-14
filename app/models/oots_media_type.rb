# The `OOTSMediaTypes` code list published with the TDD, which
# `R-EDM-REQ-C033` (FATAL) holds the `sdg:Format` of a requested distribution
# to.
#
# Copied here rather than read through `CodeListClient`, and compared exactly,
# for the reasons `LanguageCode` states: that client answers `{}` on any
# failure, deliberately, and a list that empties itself would make every value
# conformant — the opposite of what a FATAL rule asks.
#
# Distinct from what France actually serves, which is `EvidenceType::PDF` and
# nothing else: a format of this list France has no document in is refused too,
# by `EvidenceProvision::ChooseAnswer` and under `EDM:ERR:0007`, which says
# « unsupported capability » where this rule says the correspondent asked for
# something the specification does not publish at all. The two refusals are not
# the same message and must not be merged.
module OotsMediaType
  CODES = %w[image/jpeg application/json image/png application/pdf application/xml image/svg+xml].freeze

  def self.valid?(code) = CODES.include?(code)
end
