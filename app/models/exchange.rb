# One evidence exchange, shared and persisted: the worker that receives a
# gateway notification is rarely the one that handled the request, and a state
# held in memory would leave each blind to the other. Chapter 4.9 will need it
# too, to tie a second request to the first across a foreign preview space.
#
# Chapter 4.4 keeps two identifiers apart, and so does this table. `exchange_id`
# names this exchange, and every message of it carries that value — which is
# what keeps a preview's two round trips one exchange. `conversation_id`
# names a single authenticated user and their session, so it may cover several
# exchanges and is deliberately not unique.
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
class Exchange < ApplicationRecord
  include NormalisesCountryCode

  # `preview_required` — the correspondent wants the user to visit its own
  # space before it will answer. `deferred` — it answered that the evidence
  # will exist later, and named when, where it said so.
  STATUSES = %w[pending sent preview_required deferred delivered failed].freeze

  IN_PROGRESS = %w[pending sent].freeze

  # `R-EDM-ebMS-017` and `-037`: both identifiers travel in the ebMS header and
  # must be expressed as UUIDs. Public because the requester interface refuses a
  # conversation identifier of another shape before doing any work with it.
  UUID = /\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i

  # Chapter 4.4 requires every message of one exchange to reuse its
  # `ExchangeId`, which makes it — and not the conversation, that may cover
  # several exchanges — what joins an exchange to its log. Joined by that
  # identifier and not by the primary key: it is what both tables carry.
  #
  # `dependent: nil`, said explicitly: the two lifetimes are independent. The log
  # is erased at its own term, which `PurgeAuditEventsJob` keeps, and nothing
  # purges exchanges; a legal trace must never fall with the operational
  # state it relates.
  has_many :audit_events, -> { order(occurred_at: :asc) }, dependent: nil,
    primary_key: :exchange_id, foreign_key: :exchange_id, inverse_of: :exchange

  # Fixed at opening: both readings of `country_code` depend on it, and turning
  # it round would make `requester_country_code` name the solicited country.
  attr_readonly :incoming

  validates :exchange_id, presence: true, uniqueness: true
  validates :conversation_id, presence: true

  # `R-EDM-ebMS-017` and `R-EDM-ebMS-037` require both to be UUIDs, and both
  # rules are FATAL. They bind whoever emits, so they are asked of this side
  # only: an exchange a correspondent malformed must still be recorded, or
  # nothing accounts for it afterwards.
  #
  # Nothing refuses such a message yet — validating what arrives is OOTS-115 —
  # and `EvidenceProvision::AnswerRequest` reuses the identifiers it received,
  # so a malformed one travels back out in the answer France signs.
  validates :exchange_id, :conversation_id, format: { with: UUID, message: :format }, unless: :incoming?

  validates :procedure_code, :country_code, :evidence_requester_id, presence: true, unless: :incoming?
  validates :status, inclusion: { in: STATUSES }

  # A foreign correspondent chooses this value and a browser follows it as a
  # link: the parser vets its scheme, and nothing may persist one it rejected.
  validates :preview_location,
    format: { with: %r{\Ahttps?://}, message: :format },
    allow_nil: true

  # Chapter 4.4, table « Evidence Exchange Timeouts »: past the interval the
  # deployment configures, an exchange this side opened and nobody settled is a
  # failure. Counted from the opening, the one instant that does not move —
  # `updated_at` follows every write and `settled_at` is what expiring writes.
  #
  # Outgoing only. Where France answers, the timeout is an act of emission and
  # `EvidenceProvision::AnswerRequest` carries it out while the correspondent is
  # still addressable; a row written here would name an error nobody was sent.
  scope :expired, -> { where(status: IN_PROGRESS, incoming: false, created_at: ...Settings.requester_timeout.ago) }

  # Where France asks, an exchange goes pending → sent → delivered, preview and
  # deferral aside; where it answers, pending → delivered, deferred or failed.
  # `preview_required` describes the requesting side alone.
  def sent! = settle({ status: 'sent', settled_at: nil })

  def preview_required!(location) = answered(status: 'preview_required', preview_location: location)

  # A correspondent announcing a date has answered, and chapter 4.5.2 sends the
  # portal back with a new Evidence Request « at the time of availability ». So
  # a settled state and not a waiting one — nothing further arrives on this
  # exchange, and `IN_PROGRESS` leaves it out.
  def deferred!(available_at) = answered(status: 'deferred', response_available_at: available_at)

  def delivered! = answered(status: 'delivered')

  def failed!(code:, description:)
    answered(status: 'failed', edm_error_code: code, error_description: description)
  end

  # The `failed` status and `EDM:ERR:0005`, not a status of its own: a
  # correspondent that times out on us answers exactly this code, and both must
  # read the same.
  #
  # Straight to `settle` and not through `failed!`: this writes a presumption,
  # which overrules nothing.
  def expire!
    settle({ status: 'failed', edm_error_code: EdmException::TIMEOUT.code,
             error_description: I18n.t('models.exchange.expired'), presumed_at: Time.current })
  end

  def settled? = !status.in?(IN_PROGRESS)

  # Settled by this side giving up rather than by anything a correspondent said.
  # Recorded when `expire!` writes it, not read back from what it wrote: a
  # correspondent reaching its own deadline answers `EDM:ERR:0005` too, and the
  # two must not be told apart by a code they share.
  def presumed? = presumed_at.present?

  # Chapter 4.4 correlates a response to its request by this identifier. An
  # exchange recording none is not an exchange recording a different one: those
  # opened before the column existed carry nothing to compare against, and
  # refusing them would break the ones in flight at deployment.
  def answers?(request_id) = self.request_id.blank? || self.request_id == request_id

  # `IncomingMessage::SettleExchange` turns away a response to an exchange
  # already answered, deciding on the exchange as it read it — and what that
  # decision protects is an HTTP call nothing takes back, so two workers pass
  # the guard before either writes. This is the reservation only one of them
  # takes: a single statement moves the column from free to taken, and the row
  # count says who moved it. Under `read committed` the loser re-evaluates the
  # condition against the row the winner committed, and matches nothing.
  #
  # It lapses once it is itself past the interval `expired` applies — which is
  # always after the exchange has passed it too, a reservation being taken on a
  # row that already exists and therefore never standing older than it. So
  # nothing overtakes a handover under way while the exchange is still one
  # nobody has given up on, however slow — `EvidenceForwarder` sets no deadline
  # of its own. Past that, the sweep has given the exchange up, and a
  # reservation nobody could release — a worker killed mid-handover writes
  # nothing back — must stop holding a row no answer could otherwise reach.
  def claim_delivery!
    row = self.class.where(id:)

    row.where(delivering_at: nil)
      .or(row.where(delivering_at: ...Settings.requester_timeout.ago))
      .update_all(delivering_at: Time.current) == 1
  end

  # Which way the exchange runs, as the console words it.
  def direction = incoming? ? :incoming : :outgoing

  # Whose procedure this is. A procedure belongs to the country that requests —
  # `Directories::CommonServices#first_requirement` asks the Evidence Broker
  # about it under France's own code — so France declares it when France asks,
  # and the correspondent does when the correspondent asks.
  def requester_country_code = incoming? ? country_code : Settings.common_services_country_code

  # The country the evidence is asked of, and the mirror of the one above.
  def solicited_country_code = incoming? ? Settings.common_services_country_code : country_code

  private

  # What an answer records, as opposed to what `expire!` presumes. An answer may
  # overrule the presumption — the one settled state nothing actually produced,
  # which an answer refutes by arriving — where the presumption overrules
  # nothing: a guess never displaces what happened.
  #
  # The error columns are cleared unless the answer names its own, so that an
  # exchange which stops failing stops naming a failure.
  def answered(attributes)
    settle({ edm_error_code: nil, error_description: nil, presumed_at: nil }.merge(attributes),
      over_presumption: true)
  end

  # Two races meet here, and this lock decides both. The fallback sweep can pick
  # up a message the push notification also delivered, so two workers record two
  # outcomes on one exchange; and `ExpireExchangesJob` runs on its own
  # worker, so it can reach a row an answer has settled since its batch was
  # read. `with_lock` and not a bare guard, which both would pass before either
  # committed; `update!` and not `update_all`, which would skip the validations.
  def settle(attributes, over_presumption: false)
    with_lock do
      return self if settled? && !(over_presumption && presumed?)

      update!({ settled_at: Time.current }.merge(attributes))
    end

    self
  end
end
