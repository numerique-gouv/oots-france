# The question the resolution page asks the directories: which procedure, in
# which country, and — once the answer is on screen — which requirement and
# which evidence type to carry on with.
#
# The last two are how an operator steps aside from what a request would have
# done, which is to keep the first of every list.
class ResolutionFilter
  include ActiveModel::Model
  include ActiveModel::Attributes
  include SubmittedCriteria

  attribute :procedure_code, :string
  attribute :country_code, :string
  attribute :requirement_id, :string
  attribute :evidence_type_id, :string

  validates_country_code

  def country = country_code.presence&.upcase

  # Nothing goes out until both are named: the page opens on a form, and an
  # operator arriving from an exchange finds it already filled in.
  def asked? = valid? && procedure_code.present? && country.present?

  # Compacted after the overrides rather than before — the opposite of the
  # order the concern uses — so that choosing another requirement can drop the
  # evidence type chosen under the previous one by passing it as nil.
  def to_query(overrides = {})
    attributes.symbolize_keys.merge(overrides).compact_blank
  end
end
