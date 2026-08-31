# An obligation a procedure rests on, as the Evidence Broker publishes it
# (chapter 3.2.4). Its identifier is a Semantic Repository URL, and it is what
# the second Evidence Broker query takes.
#
# `reference_frameworks` are the national procedures declaring it. The
# acceptance catalogue holds 53 requirements for 687 declarations, the most
# cited of them carrying 48 — which is why the directory nests them here
# rather than publishing them apart.
#
# Validated on demand rather than on reading: a request writes this into its
# `Requirements` slot and must refuse an identifier the rules would reject,
# where a catalogue entry the console can only display half of is still worth
# displaying.
class Requirement
  include ActiveModel::Model
  include ActiveModel::Attributes
  include StrictValidation
  include SemanticRepositoryAsset
  include Described

  # R-EDM-REQ-C008: a Semantic Repository URL ending in a UUID, the optional
  # midfix naming the environment — `sr.acc` on acceptance, `sr` in production.
  # Lower-case hexadecimal, that rule carrying no `i` flag.
  IDENTIFIER = %r{\Ahttps://sr(\.[a-zA-Z]+)?\.oots\.tech\.ec\.europa\.eu/requirements/
                  [a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}\z}x

  attribute :id, :string

  # { 'EN' => '(TEST) Test Requirement', 'FI' => 'Testivaatimus' }
  attr_reader :descriptions, :details, :reference_frameworks

  validates :id, format: { with: IDENTIFIER, message: :format }
  # R-EDM-REQ-C010 and C094 make `lang` mandatory on the `sdg:Name` and the
  # `sdg:Description` a request carries; a wording the directory published
  # without one reaches `by_language` under a nil key, and would go out as
  # `lang=""`, which both rules refuse as fatal.
  validate :wordings_name_their_language

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

  private

  def wordings_name_their_language
    return if descriptions.keys.all?(&:present?) && details.keys.all?(&:present?)

    errors.add(:base, :unlabelled_wording)
  end
end
