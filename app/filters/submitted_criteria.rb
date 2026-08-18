# What every filter of this application does with the query string it is built
# from: permit its own attributes, and keep a copy of what was submitted before
# typing made of it what it could.
#
# That copy is the whole point. `ActiveModel::Type::Date` answers nil for a
# string it cannot read, and `params.permit` drops a permitted key whose value
# has the wrong shape — an array where a string was expected. Neither leaves
# any trace, so a criterion the page cannot honour would silently widen the
# listing instead of narrowing it, under a heading claiming the opposite.
module SubmittedCriteria
  extend ActiveSupport::Concern

  included do
    validate :reject_unreadable_criteria
  end

  class_methods do
    # Derived rather than restated: a list written out beside the attributes
    # would be a second place to remember, and forgetting it there silences a
    # criterion without a word.
    def permitted = attribute_names.map(&:to_sym)

    def from(params)
      new(
        **params.permit(*permitted).to_h.symbolize_keys,
        submitted: params.to_unsafe_h.symbolize_keys.slice(*permitted),
      )
    end
  end

  # Read-only and set at construction, so it cannot drift from the attributes
  # it is compared against. Built without it — from values already typed, as a
  # console or a spec does — there is nothing submitted to find fault with.
  attr_reader :submitted

  def initialize(submitted: {}, **attributes)
    @submitted = submitted
    super(**attributes)
  end

  # The criteria as a link carries them, blanks dropped: what was not asked
  # has no place in an address.
  def to_query(overrides = {})
    attributes.symbolize_keys.compact_blank.merge(overrides)
  end

  # A criterion submitted and lost on the way in. Read as one nobody submitted,
  # it would widen a listing instead of narrowing it, so every reader of a
  # criterion has to be able to ask.
  #
  # It answers on the criterion named and on nothing else: a page reading one
  # of them must not be silenced by another it does not use.
  #
  # The test holds for the types the filters carry today — `:string` and
  # `:date`, which come back nil when unreadable. It does not generalise:
  # `ActiveModel::Type::Integer` reads what it cannot make sense of as zero, so
  # a filter carrying one checks it itself — `ConversationFilter` does for its
  # page number — and a `:boolean` attribute would need the same care.
  def unreadable?(name) = submitted[name].present? && public_send(name).blank?

  private

  def reject_unreadable_criteria
    self.class.permitted.each { |name| errors.add(name, :unreadable) if unreadable?(name) }
  end
end
