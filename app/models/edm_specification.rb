# The version of the Evidence Data Model the messages declare.
#
# It travels twice: in the `SpecificationIdentifier` slot of every message body,
# and in the `SpecificationId` ebMS property. The TDD require it to match the
# `ConformsTo` published by the Access Service the requester selected in the
# DSD. See `docs/versions_tdd.md`.
module EdmSpecification
  IDENTIFIER = 'oots-edm:v2.0'.freeze

  # Asked by both readers of an incoming message — the ebMS property and the
  # body slot — which would otherwise each decide what counts as the announced
  # version.
  def self.matches?(announced) = announced == IDENTIFIER
end
