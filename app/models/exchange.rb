# One evidence exchange, shared and persisted: the worker that receives a
# gateway notification is rarely the one that handled the request, and a state
# held in memory would leave each blind to the other. Chapter 4.9 needs it too,
# to tie a second request to the first across a preview space — on the 2.0
# line, where the `ExchangeId` names it.
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
# supplies, and the exchange advances without keeping it — the portal gives it
# again when it confirms a preview, and `request_basis` keeps everything else
# the second request repeats. The one exception on this side is a preview France
# answers, whose `PreviewSession` keeps what chapter 4.9 asks for, encrypted,
# and not here.
class Exchange < ApplicationRecord
  include NormalisesCountryCode

  IN_PROGRESS = %w[pending sent].freeze

  # Where France asks, an exchange goes pending → sent → delivered, preview and
  # deferral aside; where it answers, pending → delivered, deferred or failed.
  # `declined` — the user saw the evidence in a correspondent's preview space and
  # used none of it, which chapter 4.9 §1 has the second response say with an
  # empty list: an outcome, and not a failure. `unmatched` — the same empty list
  # answering the first request, no preview having taken place: the provider
  # found no evidence to match, chapter 4.9 §2, step 4.
  # `preview_required` — the user must visit a preview space before the
  # answer — is where either side stands between the two round trips of
  # chapter 4.9: France asking, a correspondent sent it there; France answering,
  # it sent the user to its own. `deferred` — it answered that the evidence will
  # exist later, and named when, where it said so.
  #
  # Every answer may also reach a `failed` exchange, but only one the expiry
  # sweep presumed: an answer refutes a guess, where a guess displaces nothing.
  # That is the whole of `if: :refutable?`, written here as a condition of the
  # transition rather than argued in a private method — it is the rule this
  # table exists to state.
  #
  # Nothing here takes a lock. The two races an exchange runs into are settled
  # by the `with_lock` of `fire` below, inside which every event is triggered.
  state_machine :status, initial: :pending do
    state :pending, :sent, :preview_required, :deferred, :delivered, :declined, :unmatched, :failed

    # From `sent` as well as from `pending`: a submission repeated says the same
    # thing twice, which is not a contradiction to refuse.
    event :transmit do
      transition from: %i[pending sent], to: :sent
    end

    event :require_preview do
      transition from: %i[pending sent], to: :preview_required
      transition from: :failed, to: :preview_required, if: :refutable?
    end

    # Chapter 4.7 §2.5.2: the second request of a preview reuses the
    # `ExchangeId` of the first, and reopens the row the first one left.
    event(:resume) { transition from: :preview_required, to: :pending }

    event :defer do
      transition from: %i[pending sent], to: :deferred
      transition from: :failed, to: :deferred, if: :refutable?
    end

    event :deliver do
      transition from: %i[pending sent], to: :delivered
      transition from: :failed, to: :delivered, if: :refutable?
    end

    event :decline do
      transition from: %i[pending sent], to: :declined
      transition from: :failed, to: :declined, if: :refutable?
    end

    event :match_nothing do
      transition from: %i[pending sent], to: :unmatched
      transition from: :failed, to: :unmatched, if: :refutable?
    end

    event :record_failure do
      transition from: %i[pending sent], to: :failed
      transition from: :failed, to: :failed, if: :refutable?
    end

    # No `refutable?` line, and that is the rule: giving up on an exchange
    # overrules nothing, not even an earlier guess. Named for what it does
    # rather than `expire`, which would generate an `expire!` over the public
    # method below. From `preview_required` too: the portal that never confirms
    # leaves the exchange there, and T2 of chapter 4.4.3 bounds that wait.
    event :presume_timeout do
      transition from: %i[pending sent preview_required], to: :failed
    end
  end

  # Read off the machine rather than declared beside it, so that the two cannot
  # drift. It carries no further: `ExchangeStatusComponent::BADGES` and the
  # `admin.journal.exchanges.statuses` of `fr.yml` spell the eight out again,
  # and a state added here would fall back to their defaults until someone wrote
  # it there too.
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

  # The EDM version this exchange is conducted in, as the object rather than as
  # the string the column stores. Chapter 4.7 §2.6.2 has every message of one
  # exchange carry the same version, so this is what an answer is written in and
  # what a response is judged against — settled by `EvidenceRequest::ChooseSpecification`
  # where France asks, and read off the request where France answers.
  attribute :specification, EdmSpecification::Type.new

  # What the second request of a preview repeats of the first, written when the
  # first is emitted. `RequestBasis` says why it is kept rather than asked again.
  attribute :request_basis, RequestBasis::Type.new

  validates :exchange_id, presence: true, uniqueness: true
  validates :conversation_id, presence: true

  # `R-EDM-ebMS-017` and `R-EDM-ebMS-037` require both to be UUIDs, and both
  # rules are FATAL. They bind whoever emits, so they are asked of this side
  # only: an exchange a correspondent malformed must still be recorded, or
  # nothing accounts for it afterwards.
  #
  # What keeps a malformed one from travelling back out is not this validation.
  # An answer reuses the two identifiers of the request it answers, chapter 4.4
  # having every message of one exchange carry the same `ExchangeId` — so
  # `EvidenceProvision::RejectMalformedIdentifiers` refuses to answer at all
  # when either breaks the two rules, before anything is built on them.
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
  # `EvidenceProvision::ChooseAnswer` has had its own chance to return the
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
  # which chapter 4.4.3 lets it decide — `ResponseDeadline` is that reading, and
  # holds the requester's own duration. `none` and not an impossible condition:
  # a sweep that gave no exchange up is what an absent timeout means.
  #
  # Nor a received exchange whose answer a preview holds: chapter 4.9 §3
  # withholds it until the user decides, and T3 of `PreviewSession`, not T1,
  # is what bounds that wait.
  #
  # Where France asks and a correspondent sent the user to a preview, T1 gives
  # way to the two other lines of the same table: T2 bounds how long the portal
  # may take to confirm, counted from the exception that asked — `settled_at` —
  # and T3 how long the second response may take, counted from the
  # confirmation. From the confirmation and not from the submission it leads
  # to: the two are one gateway call apart, and a worker that died between them
  # leaves an exchange this sweep must still be able to close.
  scope :expired, lambda {
    deadline = ResponseDeadline.for_requester
    next none if deadline.nil?

    in_progress = where(status: IN_PROGRESS)
    outgoing = in_progress.where(incoming: false)

    outgoing.where(preview_confirmed_at: nil, created_at: ...deadline)
      .or(outgoing.where(preview_confirmed_at: ...ResponseDeadline.for_second_response))
      .or(where(incoming: false, status: 'preview_required', settled_at: ...ResponseDeadline.for_redirection))
      .or(in_progress.where(incoming: true, ebms_sent_at: ...deadline))
      .where.not(exchange_id: PreviewSession.holding.select(:answering_exchange_id))
  }

  # Which exchange a message that has just arrived belongs to.
  #
  # The `ExchangeId` where the message carries one: chapter 4.4 has every
  # message of an exchange reuse it, and 2.0 puts it in a header property.
  # Matched on the identifier alone, direction included: the end-to-end scenario
  # loops through a single gateway, where France is both correspondents and one
  # identifier legitimately names both sides.
  #
  # The 1.2 line carries no such property — `R-EDM-ebMS-037` is a rule of 2.0.1
  # alone — so what names the exchange there is the request: the `@id` of a
  # request received, the `@requestId` a response or an error echoes back.
  #
  # And where a 1.2 message carries neither — a payload nobody could read, an
  # error response that `R-EDM-ERR-C025` lets omit its `requestId` — the
  # conversation, and only where it holds a single exchange still in progress.
  # Chapter 4.7 v1.2.3 §2.5 ties a conversation to one authenticated user's
  # session rather than to one exchange, so a conversation covering two says
  # nothing about which of them a message belongs to. The caller passes it or
  # withholds it: a request arriving opens an exchange of its own, where an
  # answer settles one that is waiting.
  def self.correlate(exchange_id:, request_id:, conversation_id: nil)
    return find_by(exchange_id:) if exchange_id.present?
    return find_by(request_id:) if request_id.present?
    return if conversation_id.blank?

    # Loaded before it is counted: `one?` and `first` on a relation are two
    # queries for one question, and the answer needs the row anyway.
    waiting = where(conversation_id:, status: IN_PROGRESS).to_a

    waiting.first if waiting.one?
  end

  # `message_id` is what the gateway called the request, and what its
  # notifications on that message name. The second request of a preview
  # replaces the first's: that one was delivered, since it was answered.
  def sent!(message_id) = fire(:transmit, settled_at: nil, request_message_id: message_id)

  # What the correspondent said of its preview beyond the address — the
  # descriptions a portal builds its launch page from (chapter 4.9 §5), and on
  # the 1.2 line the method to reach it with — kept for the confirmation to
  # come. France answering passes neither: it holds them in `PreviewSession`.
  def preview_required!(location, descriptions: nil, method: nil)
    answered(:require_preview, preview_location: location, preview_descriptions: descriptions,
      preview_method: method)
  end

  def reopen!(request_id) = fire(:resume, settled_at: nil, request_id:)

  # The portal confirming a preview France asked for: the row the exception
  # left is reopened for the second request (chapter 4.9 §2 step 12), under the
  # return address that request will carry. False where the exchange no longer
  # stood in `preview_required` — T2 expired it, or a concurrent confirmation
  # took it first — the lock of `fire` deciding between the two.
  def confirm_preview!(return_token:, resume_location:)
    fired?(:resume, settled_at: nil, preview_confirmed_at: Time.current, return_token:, resume_location:)
  end

  def preview_confirmed? = preview_confirmed_at.present?

  # Chapter 4.9 §5: « Return URLs shall not be accessible before the second
  # request is issued and the user is presented a link », « for a time-limited
  # period ». Open once the row has left `pending` — the second request has gone,
  # or the exchange settled since — and for T3 from the confirmation. A
  # submission the gateway refused leaves the row `failed` and so open too, on
  # an address nobody was ever handed.
  def return_open? = preview_confirmed? && !pending? && preview_confirmed_at > Settings.requester_decision_timeout.ago

  # The *Return URL* of chapter 4.9 §5, as the second request carries it: an
  # address of this deployment that sends the user back to `resume_location`.
  def return_location
    "#{Settings.oots_france_url}/retour/#{return_token}" if return_token.present?
  end

  # A correspondent announcing a date has answered, and chapter 4.5.2 sends the
  # portal back with a new Evidence Request « at the time of availability ». So
  # a settled state and not a waiting one — nothing further arrives on this
  # exchange, and `IN_PROGRESS` leaves it out.
  def deferred!(available_at) = answered(:defer, response_available_at: available_at)

  def delivered! = answered(:deliver)

  def declined! = answered(:decline)

  def unmatched! = answered(:match_nothing)

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
  # And a third where the silence was the portal's, which never confirmed the
  # preview a correspondent asked for.
  def expire!
    fire(:presume_timeout,
      edm_error_code: EdmException::TIMEOUT.code,
      error_description: I18n.t("models.exchange.expired.#{preview_required? ? :unconfirmed : direction}"),
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

  # Whether `exchange_id` is one France minted for itself and no message ever
  # carried. The `ExchangeId` property belongs to a 2.0 header, so on the 1.2
  # line both openings mint one and emit it nowhere: an operator meeting it in
  # the console would look for it in the gateway and at the correspondent in
  # vain. The exchange itself took place — its messages travelled under the
  # conversation identifier alone.
  #
  # The very predicate the header asks, rather than a second criterion written
  # beside it: the console and `app/templates/ebms_header.xml.erb` must not
  # answer the same question two different ways the day a third line is added.
  #
  # False where no version was settled: nothing then says which line the
  # exchange would have been conducted on.
  def minted_identifier? = specification.present? && !specification.exchange_named_in_header?

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
    fired?(event, **attributes)

    self
  end

  # The same, saying whether the transition took place.
  def fired?(event, **attributes)
    with_lock do
      next false unless send(:"can_#{event}?")

      assign_attributes({ settled_at: Time.current }.merge(attributes))
      send(:"#{event}!")
    end
  end
end
