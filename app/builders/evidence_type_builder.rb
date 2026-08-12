# The `sdg:DataServiceEvidenceType` naming what is being asked for.
#
# The inner `sdg:Identifier` is hard-coded: it should carry the identifier the
# Data Service Directory gives the service, which this deployment does not read
# yet. Stub 7 of `docs/reste_à_faire.md`.
#
# The default namespace declared on the element is odd — it redeclares rim on a
# `sdg:` element that needs it for nothing — but it is what correspondents
# receive today, and dropping it is a change to the payloads, to be made
# against the TDD examples and the Schematron rules rather than in passing.
class EvidenceTypeBuilder < ApplicationBuilder
  attr_reader :evidence_type

  def initialize(evidence_type:)
    @evidence_type = evidence_type
  end

  protected

  def template_name = '_evidence_type.xml.erb'
end
