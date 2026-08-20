# Everything the journal listings derive from the query string: which events to
# show, in which order, and which page of them.
#
# Sibling of `ConversationFilter`, and deliberately its twin: an operator who
# has learnt one listing of this console has learnt the other.
class AuditEventFilter
  include ActiveModel::Model
  include ActiveModel::Attributes
  include SubmittedCriteria

  PER_PAGE = 25

  attribute :event_type, :string
  attribute :procedure_code, :string
  attribute :country_code, :string
  attribute :evidence_requester_id, :string
  attribute :depuis, :date
  attribute :jusqu_a, :date
  attribute :page, :integer, default: 1

  EXACT = %i[event_type procedure_code evidence_requester_id].freeze

  validates :event_type, inclusion: { in: AuditEvent::EVENT_TYPES }, allow_blank: true
  validates_country_code
  validate :reject_inverted_period

  def apply(scope, page)
    narrow(scope)
      .order(occurred_at: :desc)
      .offset((page - 1) * PER_PAGE)
      .limit(PER_PAGE)
  end

  def total(scope) = narrow(scope).count

  def pages(total) = [(total.to_f / PER_PAGE).ceil, 1].max

  # Bounded at both ends. Below, because an offset cannot be negative; above,
  # because a page past the last would render an empty list beside a count
  # saying there is something to see.
  def page_within(total) = page.to_i.clamp(1, pages(total))

  private

  # A criterion this cannot honour narrows to nothing, and the page says which.
  # The guard lives here rather than in each caller: `narrow` is what every
  # reading goes through, and an invalid filter that widened a listing under a
  # heading claiming the opposite is the whole reason `valid?` exists.
  def narrow(scope)
    return scope.none unless valid?

    scope.where(exact_matches).where(period)
  end

  def exact_matches
    EXACT.index_with { |name| public_send(name) }
      .merge(country_code: country_code&.upcase)
      .compact_blank
  end

  # Whole days, and open at either end. On `occurred_at`, which is when the
  # thing happened, and not on `created_at`, which is when it was written.
  def period
    return {} if depuis.nil? && jusqu_a.nil?

    { occurred_at: depuis&.beginning_of_day..jusqu_a&.end_of_day }
  end

  def reject_inverted_period
    return if depuis.nil? || jusqu_a.nil? || depuis <= jusqu_a

    errors.add(:jusqu_a, :before_start)
  end
end
