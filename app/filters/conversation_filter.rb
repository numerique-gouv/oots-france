# Everything the conversation list derives from the query string: which
# exchanges to show, in which order, and which page of them.
#
# It sits above the model on purpose — `Conversation` knows nothing of
# `params` — and below the controller, which builds no query of its own.
class ConversationFilter
  include ActiveModel::Model
  include ActiveModel::Attributes

  PER_PAGE = 25

  attribute :status, :string
  attribute :country_code, :string
  attribute :evidence_requester_id, :string
  attribute :procedure_code, :string
  attribute :depuis, :date
  attribute :jusqu_a, :date
  attribute :page, :integer, default: 1

  # Derived rather than restated: a second list would be a second place to
  # remember, and forgetting it there silences a criterion without a word.
  PERMITTED = attribute_names.map(&:to_sym).freeze

  # Those compared as they are. The country is upcased, and the period is an
  # interval rather than a value.
  EXACT = %i[status evidence_requester_id procedure_code].freeze

  # What the operator submitted, before typing made of it what it could:
  # `ActiveModel::Type::Date` answers `nil` for a string it cannot read, and
  # `params.permit` drops a permitted key whose value has the wrong shape.
  # Without this copy, neither leaves any trace to notice.
  #
  # Read-only and set at construction, so it cannot drift from the attributes
  # it is compared against. Built without it — from values already typed, as a
  # console or a spec does — there is nothing submitted to find fault with.
  attr_reader :submitted

  validates :status, inclusion: { in: Conversation::STATUSES }, allow_blank: true
  validate :reject_unreadable_criteria
  validate :reject_inverted_period

  def initialize(submitted: {}, **attributes)
    @submitted = submitted
    super(**attributes)
  end

  def self.from(params)
    new(
      **params.permit(*PERMITTED).to_h.symbolize_keys,
      submitted: params.to_unsafe_h.symbolize_keys.slice(*PERMITTED),
    )
  end

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

  def to_query(overrides = {})
    attributes.symbolize_keys.compact_blank.merge(overrides)
  end

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

  def reject_unreadable_criteria
    PERMITTED.each do |name|
      next if submitted[name].blank? || public_send(name).present?

      errors.add(name, :unreadable)
    end
  end

  # A period read the wrong way round matches nothing, which on screen is
  # indistinguishable from an exchange that never happened.
  def reject_inverted_period
    return if depuis.nil? || jusqu_a.nil? || depuis <= jusqu_a

    errors.add(:jusqu_a, :before_start)
  end
end
