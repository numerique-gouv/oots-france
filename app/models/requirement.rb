# An obligation a procedure rests on, as the Evidence Broker publishes it
# (chapter 3.2.4). Its identifier is a Semantic Repository URL, and it is what
# the second Evidence Broker query takes.
#
# `reference_frameworks` are the national procedures declaring it. The
# acceptance catalogue holds 53 requirements for 687 declarations, the most
# cited of them carrying 48 — which is why the directory nests them here
# rather than publishing them apart.
#
# Nothing is validated: only `id` is read on the path of a real request, where
# `RequirementsResponseParser` already refuses an answer without one. A
# catalogue entry the console can only display half of is still worth
# displaying.
class Requirement
  include ActiveModel::Model
  include ActiveModel::Attributes
  include SemanticRepositoryAsset
  include Described

  attribute :id, :string

  # { 'EN' => '(TEST) Test Requirement', 'FI' => 'Testivaatimus' }
  attr_reader :descriptions, :details, :reference_frameworks

  def initialize(attributes = {})
    @descriptions = attributes.delete(:descriptions) || {}
    @details = attributes.delete(:details) || {}
    @reference_frameworks = attributes.delete(:reference_frameworks) || []
    super

    # The directory nests declarations inside the requirement; a listing of
    # procedures walks the graph the other way, and would otherwise have to
    # carry the pairing alongside every declaration it moves.
    @reference_frameworks.each { |framework| framework.requirement = self }
  end

  def detail = in_preferred_language(details)

  # Blank rather than nil throughout: this holds whatever the caller built its
  # declarations from, and a code or a country named « » is not one.
  def procedure_codes = reference_frameworks.filter_map { |declared| declared.procedure_code.presence }.uniq

  def countries = reference_frameworks.filter_map { |declared| declared.country.presence }.uniq

  def declared_in(country) = reference_frameworks.select { |declared| declared.country == country }
end
