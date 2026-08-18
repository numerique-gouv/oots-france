# Everything the conversation list derives from the query string: which
# exchanges to show, in which order, and which page of them.
#
# It sits above the model on purpose — `Conversation` knows nothing of
# `params` — and below the controller, which builds no query of its own.
class ConversationFilter
  include ActiveModel::Model
  include ActiveModel::Attributes
  include SubmittedCriteria

  PER_PAGE = 25

  attribute :status, :string
  attribute :country_code, :string
  attribute :evidence_requester_id, :string
  attribute :procedure_code, :string
  attribute :depuis, :date
  attribute :jusqu_a, :date
  attribute :page, :integer, default: 1

  # Those compared as they are. The country is upcased, and the period is an
  # interval rather than a value.
  EXACT = %i[status evidence_requester_id procedure_code].freeze

  validates :status, inclusion: { in: Conversation::STATUSES }, allow_blank: true
  validate :reject_inverted_period

  # A criterion this cannot honour narrows to nothing, and the page says which.
  # Dropping it would show every exchange under a heading claiming the
  # opposite, and nothing on screen would tell an operator the two apart.
  def apply(scope, page)
    return scope.none unless valid?

    narrow(scope)
      .order(created_at: :desc)
      .offset((page - 1) * PER_PAGE)
      .limit(PER_PAGE)
  end

  def total(scope) = valid? ? narrow(scope).count : 0

  def pages(total) = [(total.to_f / PER_PAGE).ceil, 1].max

  # Bounded at both ends. Below, because an offset cannot be negative; above,
  # because PostgreSQL refuses one wider than a 64-bit integer — and because a
  # page past the last would otherwise render an empty list beside a count
  # saying there is something to see.
  def page_within(total) = page.to_i.clamp(1, pages(total))

  private

  def narrow(scope) = scope.where(exact_matches).where(period)

  # The conditions are passed positionally: `where(**{})` is `where()`, which
  # answers a `WhereChain` waiting for a `not` rather than the relation itself.
  def exact_matches
    EXACT.index_with { |name| public_send(name) }
      .merge(country_code: country_code&.upcase)
      .compact_blank
  end

  # Whole days, and open at either end: a period given by one bound only is the
  # ordinary way of asking « depuis » or « jusqu'à ».
  def period
    return {} if depuis.nil? && jusqu_a.nil?

    { created_at: depuis&.beginning_of_day..jusqu_a&.end_of_day }
  end

  # A period read the wrong way round matches nothing, which on screen is
  # indistinguishable from an exchange that never happened.
  def reject_inverted_period
    return if depuis.nil? || jusqu_a.nil? || depuis <= jusqu_a

    errors.add(:jusqu_a, :before_start)
  end
end
