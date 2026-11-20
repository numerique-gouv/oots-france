# The `OOTSMediaTypes` code list published with the TDD, which
# `R-EDM-REQ-C033` (FATAL) holds the `sdg:Format` of a requested distribution
# to.
#
# Copied here rather than read through `CodeListClient`, and compared exactly,
# for the reasons `LanguageCode` states: that client answers `{}` on any
# failure, deliberately, and a list that empties itself would make every value
# conformant — the opposite of what a FATAL rule asks.
#
# Distinct from what France serves as a provider: a format of this list in
# which it has no document is refused by `EvidenceProvision::ChooseAnswer`
# under `EDM:ERR:0007`, which says
# « unsupported capability » where this rule says the correspondent asked for
# something the specification does not publish at all. The two refusals are not
# the same message and must not be merged.
module OotsMediaType
  # Each code, with the extension a file of it is saved under.
  EXTENSIONS = {
    'image/jpeg' => 'jpg', 'application/json' => 'json', 'image/png' => 'png',
    'application/pdf' => 'pdf', 'application/xml' => 'xml', 'image/svg+xml' => 'svg',
  }.freeze

  CODES = EXTENSIONS.keys.freeze

  def self.valid?(code) = CODES.include?(code)
end
