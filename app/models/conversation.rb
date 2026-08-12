# The state of one exchange, shared and persisted: the worker that receives a
# gateway notification is rarely the one that handled the request, and a state
# held in memory would leave each blind to the other. Chapter 4.9 will need it
# too, to tie a second request to the first across a foreign preview space.
#
# **No personal data.** The beneficiary lives in the token the requester
# supplies, and the exchange advances without keeping it.
class Conversation < ApplicationRecord
  # `preview_required` — the correspondent wants the user to visit its own
  # space before it will answer.
  STATUSES = %w[pending sent preview_required delivered failed].freeze

  IN_PROGRESS = %w[pending sent].freeze

  validates :conversation_id, presence: true, uniqueness: true
  validates :procedure_code, :country_code, :evidence_requester_id, presence: true
  validates :status, inclusion: { in: STATUSES }

  # A foreign correspondent chooses this value and a browser follows it as a
  # link: the parser vets its scheme, and nothing may persist one it rejected.
  validates :preview_location,
    format: { with: %r{\Ahttps?://}, message: :format },
    allow_nil: true

  def sent! = settle(status: 'sent', settled_at: nil)

  def preview_required!(location) = settle(status: 'preview_required', preview_location: location)

  def delivered! = settle(status: 'delivered')

  def failed!(code:, description:)
    settle(status: 'failed', edm_error_code: code, error_description: description)
  end

  def settled? = !status.in?(IN_PROGRESS)

  private

  # The fallback sweep can pick up a message the push notification also
  # delivered, so two workers race to record two outcomes on one exchange.
  # `with_lock` and not a bare guard, which both would pass before either
  # committed; `update!` and not `update_all`, which would skip the validations.
  def settle(attributes)
    with_lock do
      return self if settled?

      update!({ settled_at: Time.current }.merge(attributes))
    end

    self
  end
end
