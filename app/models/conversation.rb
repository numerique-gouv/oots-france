# The state of one exchange, shared and persisted: the worker that receives a
# gateway notification is rarely the one that handled the request, and a state
# held in memory would leave each blind to the other. Chapter 4.9 will need it
# too, to tie a second request to the first across a foreign preview space.
#
# Both directions get a row. `incoming` says which: France asking a
# correspondent, or a correspondent asking France. `country_code` holds the
# correspondent's country either way — solicited where France asks, requesting
# where France answers — and `solicited_country_code` and
# `requester_country_code` are the two readings of it.
#
# A body too malformed to read names nothing at all, so the three columns an
# outgoing exchange always knows are required of that direction only.
#
# **No personal data.** The beneficiary lives in the token the requester
# supplies, and the exchange advances without keeping it.
class Conversation < ApplicationRecord
  include NormalisesCountryCode

  # `preview_required` — the correspondent wants the user to visit its own
  # space before it will answer.
  STATUSES = %w[pending sent preview_required delivered failed].freeze

  IN_PROGRESS = %w[pending sent].freeze

  # Le journal de cet échange, joint par l'identifiant ebMS et non par la clé
  # primaire — c'est lui que les deux tables portent.
  #
  # `dependent: nil`, dit explicitement : les deux durées de vie sont
  # indépendantes. Le journal s'efface à son propre terme, que
  # `PurgeAuditEventsJob` tient, et rien ne purge les conversations ; une trace
  # légale ne doit jamais tomber avec l'état opérationnel qu'elle relate.
  has_many :audit_events, -> { order(occurred_at: :asc) }, dependent: nil,
    primary_key: :conversation_id, foreign_key: :conversation_id, inverse_of: :conversation

  # Figé à l'ouverture : les deux lectures de `country_code` en dépendent, et le
  # retourner ferait dire à `requester_country_code` le pays sollicité.
  attr_readonly :incoming

  validates :conversation_id, presence: true, uniqueness: true
  validates :procedure_code, :country_code, :evidence_requester_id, presence: true, unless: :incoming?
  validates :status, inclusion: { in: STATUSES }

  # A foreign correspondent chooses this value and a browser follows it as a
  # link: the parser vets its scheme, and nothing may persist one it rejected.
  validates :preview_location,
    format: { with: %r{\Ahttps?://}, message: :format },
    allow_nil: true

  # Where France asks, an exchange goes pending → sent → delivered, preview
  # aside; where it answers, pending → delivered or failed. The two states in
  # between describe the requesting side alone.
  def sent! = settle(status: 'sent', settled_at: nil)

  def preview_required!(location) = settle(status: 'preview_required', preview_location: location)

  def delivered! = settle(status: 'delivered')

  def failed!(code:, description:)
    settle(status: 'failed', edm_error_code: code, error_description: description)
  end

  def settled? = !status.in?(IN_PROGRESS)

  # Whose procedure this is. A procedure belongs to the country that requests —
  # `Directories::CommonServices#first_requirement` asks the Evidence Broker
  # about it under France's own code — so France declares it when France asks,
  # and the correspondent does when the correspondent asks.
  def requester_country_code = incoming? ? country_code : Settings.common_services_country_code

  # The country the evidence is asked of, and the mirror of the one above.
  def solicited_country_code = incoming? ? Settings.common_services_country_code : country_code

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
