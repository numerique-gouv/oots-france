# The requirements a procedure imposes, as the Evidence Broker returns them
# (chapter 3.2.4).
#
# Every parameter of that query is optional, so the same answer is either the
# requirements of one procedure in one jurisdiction, or — asked with nothing —
# the whole catalogue the Evidence Broker holds. `Directories::Catalogue` reads
# it the second way, `Directories::CommonServices` the first.
class RequirementsResponseParser < CommonServicesResponseParser
  include RequirementReading

  def requirements = @read

  private

  def read = records(REQUIREMENT).map { |declared| build_requirement(declared) }
end
