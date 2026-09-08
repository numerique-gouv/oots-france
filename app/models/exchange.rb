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

  IN_PROGRESS = %w[pending sent].freeze

  # Where France asks, an exchange goes pending → sent → delivered, preview and
  # deferral aside; where it answers, pending → delivered, deferred or failed.
  # `preview_required` — the correspondent wants the user to visit its own space
  # before it will answer — describes the requesting side alone. `deferred` — it
  # answered that the evidence will exist later, and named when, where it said
  # so.
  #
  # Every one of the four answers may also reach a `failed` exchange, but only
  # one the expiry sweep presumed: an answer refutes a guess, where a guess
  # displaces nothing. That is the whole of `if: :refutable?`, written here as a
  # condition of the transition rather than argued in a private method — it is
  # the rule this table exists to state.
  #
  # Nothing here takes a lock. The two races an exchange runs into are settled
  # by the `with_lock` of `fire` below, inside which every event is triggered.
  state_machine :status, initial: :pending do
    state :pending, :sent, :preview_required, :deferred, :delivered, :failed

    # From `sent` as well as from `pending`: a submission repeated says the same
    # thing twice, which is not a contradiction to refuse.
    event :transmit do
      transition from: %i[pending sent], to: :sent
    end

    event :require_preview do
      transition from: %i[pending sent], to: :preview_required
      transition from: :failed, to: :preview_required, if: :refutable?
    end

    event :defer do
      transition from: %i[pending sent], to: :deferred
      transition from: :failed, to: :deferred, if: :refutable?
    end

    event :deliver do
      transition from: %i[pending sent], to: :delivered
      transition from: :failed, to: :delivered, if: :refutable?
    end

    event :record_failure do
      transition from: %i[pending sent], to: :failed
      transition from: :failed, to: :failed, if: :refutable?
    end

    # No `refutable?` line, and that is the rule: giving up on an exchange
    # overrules nothing, not even an earlier guess. Named for what it does
    # rather than `expire`, which would generate an `expire!` over the public
    # method below.
    event :presume_timeout do
      transition from: %i[pending sent], to: :failed
    end
  end

  # Read off the machine rather than declared beside it, so that the two cannot
  # drift. It carries no further: `ExchangeStatusComponent::BADGES` and the
  # `models.exchange.statuses` of `fr.yml` spell the six out again, and a state
  # added here would fall back to their defaults until someone wrote it there
  # too.
  STATUSES = state_machines[:status].states.map { |state| state.name.to_s }.freeze

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
  # What keeps a malformed one from travelling back out is not this validation
  # but `EvidenceProvision::AnswerRequest`, which reuses the identifiers it
  # received and refuses to answer at all when either breaks the two rules.
  validates :exchange_id, :conversation_id, format: { with: UUID, message: :format }, unless: :incoming?

  validates :procedure_code, :country_code, :evidence_requester_id, presence: true, unless: :incoming?
  validates :status, inclusion: { in: STATUSES }

  # A foreign correspondent chooses this value and a browser follows it as a
  # link: the parser vets its scheme, and nothing may persist one it rejected.
  validates :preview_location,
    format: { with: %r{\Ahttps?://}, message: :format },
    allow_nil: true

  # Chapter 4.4, table « Evidence Exchange Timeouts »: past the interval the
  # deployment configures, an exchange nobody settled is a failure, either way
  # round. Each direction is counted from the instant that does not move for it
  # — `updated_at` follows every write and `settled_at` is what expiring writes.
  # Where France asks, that is the opening, which is also its emission. Where
  # France answers, it is the stamp the sending gateway put on the message:
  # `created_at` is only when we took it in hand, and `retention_undownloaded`
  # lets Domibus hold one for two and a half days that the fallback sweep then
  # brings back as though it had just arrived.
  #
  # The requester interval both ways, and deliberately the later of the two
  # France configures: `Settings::Contract` refuses to start unless it exceeds
  # the provider one, so a received exchange reaches this sweep only once
  # `EvidenceProvision::AnswerRequest` has had its own chance to return the
  # timeout exception while the correspondent was still addressable. Nothing is
  # emitted here — this only stops a row whose worker died from waiting for
  # ever. What interval a correspondent gives itself is its own affair and
  # unknown to us; chapter 4.4.3 leaves each portal to assume a value — « the
  # value must be assumed by the Online Procedure Portal » — so nothing is
  # timed against it.
  #
  # An exchange carrying no stamp is left out by SQL alone — a comparison
  # against `NULL` is never true — which is what leaves alone the ones opened
  # before the column. Said because it is invisible: a condition added for it
  # would be redundant, and this one reads as removable without it.
  #
  # A header whose timestamp could not be read leaves the column empty too, and
  # does not linger for it: `expired?` reads that same header, so
  # `IncomingMessage::Process` gives the message up and settles the exchange as
  # a failure in the same run.
  #
  # And no exchange at all where the deployment provides no timeout handling,
  # which chapter 4.4.3 lets it decide: « If an Online Procedure Portals
  # implements timeout, then it shall generate a timeout error » is the
  # conditional `Settings.timeout_enabled?` answers. `none` and not an
  # impossible condition, so that `Settings.requester_timeout` is not evaluated
  # either: no duration is configured on that side.
  scope :expired, lambda {
    next none unless Settings.timeout_enabled?

    deadline = Settings.requester_timeout.ago
    in_progress = where(status: IN_PROGRESS)

    in_progress.where(incoming: false, created_at: ...deadline)
      .or(in_progress.where(incoming: true, ebms_sent_at: ...deadline))
  }

  def sent! = fire(:transmit, settled_at: nil)

  def preview_required!(location) = answered(:require_preview, preview_location: location)

  # A correspondent announcing a date has answered, and chapter 4.5.2 sends the
  # portal back with a new Evidence Request « at the time of availability ». So
  # a settled state and not a waiting one — nothing further arrives on this
  # exchange, and `IN_PROGRESS` leaves it out.
  def deferred!(available_at) = answered(:defer, response_available_at: available_at)

  def delivered! = answered(:deliver)

  def failed!(code:, description:)
    answered(:record_failure, edm_error_code: code, error_description: description)
  end

  # The `failed` status and `EDM:ERR:0005`, not a status of its own: a
  # correspondent that times out on us answers exactly this code, and both must
  # read the same.
  #
  # Straight to `fire` and not through `failed!`: this writes a presumption,
  # which overrules nothing — hence its own event, which admits no presumed
  # exchange among the states it comes from.
  #
  # The phrase is the direction's, the same code covering two different things:
  # where France asks, the correspondent did not answer; where France answers,
  # nothing was emitted at all and the exchange died on the way. Not so that an
  # operator can tell which way round — the console prints the direction of its
  # own — but so as not to impute to a correspondent a silence that was ours.
  def expire!
    fire(:presume_timeout,
      edm_error_code: EdmException::TIMEOUT.code,
      error_description: I18n.t("models.exchange.expired.#{direction}"),
      presumed_at: Time.current)
  end

  def settled? = !status.in?(IN_PROGRESS)

  # Settled by this side giving up rather than by anything a correspondent said.
  # Recorded when `expire!` writes it, not read back from what it wrote: a
  # correspondent reaching its own deadline answers `EDM:ERR:0005` too, and the
  # two must not be told apart by a code they share.
  def presumed? = presumed_at.present?

  # The same question, asked of the row rather than of the object: an answer
  # clears the presumption in the very assignment whose transition this
  # condition has to admit, so a guard reading the attribute would take away
  # what it is looking for. Every other caller wants `presumed?`, which reads
  # the object it holds.
  def refutable? = presumed_at_in_database.present?

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
  # It lapses after `DELAI_RESERVATION_REMISE_MINUTES`, because a worker killed
  # mid-handover writes nothing back and a reservation nobody can release would
  # hold a row no answer could ever reach again. That setting is where the two
  # ways of being wrong are weighed: set too short it takes back a handover
  # still running — `EvidenceForwarder` sets no deadline of its own and retries
  # twice — and the same evidence goes over twice; set too long it makes a late
  # answer wait behind a reservation nothing is holding.
  #
  # Its own duration, and not the interval `expired` applies: that one is the
  # timeout of chapter 4.4.3, which a deployment may provide or not, where this
  # is a guard on two workers that stands either way.
  def claim_delivery!
    row = self.class.where(id:)

    row.where(delivering_at: nil)
      .or(row.where(delivering_at: ...Settings.delivery_lease.ago))
      .update_all(delivering_at: Time.current) == 1
  end

  # Which way the exchange runs, as the console words it.
  def direction = incoming? ? :incoming : :outgoing

  # Whose procedure this is. A procedure belongs to the country that requests —
  # `Directories::CommonServices#requirements` asks the Evidence Broker
  # about it under France's own code — so France declares it when France asks,
  # and the correspondent does when the correspondent asks.
  def requester_country_code = incoming? ? country_code : Settings.common_services_country_code

  # The country the evidence is asked of, and the mirror of the one above.
  def solicited_country_code = incoming? ? Settings.common_services_country_code : country_code

  private

  # What an answer records, as opposed to what `expire!` presumes. Which
  # exchange an answer may still reach is the machine's business — `if:
  # :refutable?` — and all this adds is what an answer writes: the error columns
  # are cleared unless the answer names its own, so that an exchange which stops
  # failing stops naming a failure.
  def answered(event, **attributes)
    fire(event, edm_error_code: nil, error_description: nil, presumed_at: nil, **attributes)
  end

  # Two races meet here, and this lock decides both. The fallback sweep can pick
  # up a message the push notification also delivered, so two workers record two
  # outcomes on one exchange; and `ExpireExchangesJob` runs on its own
  # worker, so it can reach a row an answer has settled since its batch was
  # read. `with_lock` and not a bare guard, which both would pass before either
  # committed. The event is fired inside it, the state machine taking no lock of
  # its own.
  #
  # Asked before it is fired, and then fired in its bang form: a transition no
  # `from:` admits must stay the silent non-event it has always been — the order
  # of calls is what keeps it from happening — where a row the validations
  # refuse must raise, `preview_location` being a link a correspondent chose and
  # a browser will follow.
  #
  # That refusal now reads as `StateMachines::InvalidTransition`, which carries
  # the validation message rather than the `errors` an `ActiveRecord::RecordInvalid`
  # would. Nothing rescues either today; whoever adds a `rescue` here should
  # know which one arrives.
  def fire(event, **attributes)
    with_lock do
      next unless send(:"can_#{event}?")

      assign_attributes({ settled_at: Time.current }.merge(attributes))
      send(:"#{event}!")
    end

    self
  end
end
