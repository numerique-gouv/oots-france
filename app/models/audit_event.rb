# One line of the exchange log chapter 4.8 requires, and that article 17 of the
# implementing regulation says must survive twelve months.
#
# Distinct from `Exchange`, which holds the current state of an exchange and
# carries no personal data: this one is a trace, it is append-only, and it does
# carry personal data — the chapter names *Evidence subject information* among
# what a requester and a provider must log.
#
# It is also distinct from the application logs, which rotate on their own
# schedule and are addressed to whoever operates the deployment. The audience
# here is an auditor, and the retention is a legal obligation.
class AuditEvent < ApplicationRecord
  include NormalisesCountryCode

  # `request_refused` is the one the gateway never hears about: a call this
  # application turns down produces no ebMS message at all. Article 17 does not
  # reach that far — it covers the request, the response, an error report
  # actually sent, and the eDelivery events — so recording it is this
  # deployment's own decision, taken because nothing else would hold the trace.
  # `response_refused` is its counterpart on the way in: chapter 4.4 has a
  # portal not process a response that answers a request it already answered, or
  # that names a request of someone else's. Nothing goes back to the
  # correspondent — the TDD open no error path that way — so the journal is the
  # only place the decision can be read afterwards.
  #
  # The last three are of that same family, and chapter 4.8 §3.3 says as much by
  # omission: it hands the logging of AS4 errors and SOAP faults to the access
  # points, and gives a submission that never got through no line at all, its
  # four tables describing messages that circulated. What they buy is that a
  # message we could not read, one we could not handle, and an answer France
  # built and failed to hand over stop being invisible.
  EVENT_TYPES = %w[
    request_sent request_refused response_received error_received evidence_delivered
    request_received response_sent error_sent response_refused
    message_unreadable message_unhandled answer_not_sent
  ].freeze

  encrypts :evidence_subject
  encrypts :evidence_subject_key, deterministic: true

  # The first MIME part chapter 4.8 has kept whole carries the evidence subject
  # in clear, so it belongs to the same class of data as the column above.
  # Ordinary encryption, not deterministic: nothing ever searches by it, and
  # determinism is a cost `evidence_subject_key` alone has a reason to pay.
  encrypts :regrep_body

  # What the canonical key is built from, named here because `NaturalPerson`
  # carries more than it.
  SUBJECT_FIELDS = %i[family_name given_name date_of_birth].freeze

  # The value the deterministic column is queried by, so that an auditor can
  # answer the question article 17 exists for: which data of this person
  # travelled? Case-folded, because two member states spell a name in two cases
  # and mean one person.
  #
  # It lives here rather than where it is written: a deterministic column can
  # only be searched by a value built exactly as it was stored, so whoever
  # searches has to build it the same way.
  def self.subject_key(family_name:, given_name:, date_of_birth:)
    [family_name, given_name, date_of_birth].join('|').downcase
  end

  # The two columns a subject is written as, built in one place because they
  # have to agree: the deterministic one is only searchable by a value composed
  # exactly as it was stored.
  def self.subject(person)
    return {} if person.nil?

    described = person.attributes.compact

    { evidence_subject: described.to_json, evidence_subject_key: canonical_key(described) }
  end

  # A subject that does not carry the three fields gets no key. Chapter 4.5.1
  # lets the evidence subject be an organisation, which has neither a given name
  # nor a date of birth, and a key composed of anything else would be searchable
  # by nothing: `SubjectSearch` only ever builds the triplet. The key is a local
  # convenience and not a chapter's demand, so its absence costs the trace
  # nothing — `evidence_subject` still holds everything that was read.
  #
  # Decided on the fields and not on the class of what is passed, because how
  # the key is composed belongs to the journal and not to the subject: a value
  # object serves the templates and the builders too, where a column of this
  # table means nothing.
  #
  # It rests on every subject reaching here having been validated first, which
  # both the builders of `NaturalPerson` do — `BeneficiaryToken` and
  # `EvidenceRequestParser` — since a person short of one field would otherwise
  # lose the key silently rather than fail.
  def self.canonical_key(described)
    fields = described.symbolize_keys.slice(*SUBJECT_FIELDS)

    subject_key(**fields) if fields.size == SUBJECT_FIELDS.size
  end

  # The three ebMS messages the TDD define, in each direction: which end of the
  # gateway one of them went through. The other six types are not one of those
  # three, each for its own reason — a refusal pronounced before the gateway was
  # called, the handing of the evidence to the French requester, a response
  # turned away that already has its own line, an answer the gateway never took,
  # and the two arrivals whose action named none of the three.
  #
  # Read by `db/seeds.rb` alone, to decide which demonstration events carry a
  # message identifier. No page reads them: they derive the direction from the
  # type and the country as recorded.
  SENT_BY_FRANCE = %w[request_sent response_sent error_sent].freeze
  RECEIVED_BY_FRANCE = %w[request_received response_received error_received].freeze

  # The counterpart of `Exchange`'s `has_many`, joined by the identifier of the
  # exchange — the one chapter 4.4 requires every message of it to reuse, where
  # a conversation may cover several. `optional`, and with no database
  # constraint: a refusal pronounced before any exchange was opened names none,
  # and a response can name one France never opened.
  belongs_to :exchange, primary_key: :exchange_id,
    optional: true, inverse_of: :audit_events

  scope :about_subject, ->(key) { where(evidence_subject_key: key).order(occurred_at: :desc) }

  # Chapter 4.4: « A Data Service MUST reject requests that use identifiers that
  # were used in previously processed requests. »
  #
  # `except` is the gateway message identifier of the request being handled,
  # which already has its own line here: `IncomingMessage::Process` journals
  # before it dispatches, so without it every request would look like its own
  # replay.
  #
  # Applied only when given: `where.not(message_id: nil)` reads as `IS NOT
  # NULL`, which would silently drop from the seen set any arrival that carried
  # no message identifier rather than exclude the one being handled.
  def self.request_already_received?(request_id, except: nil)
    return false if request_id.blank?

    seen = where(event_type: 'request_received', request_id:)
    seen = seen.where.not(message_id: except) if except.present?

    seen.exists?
  end

  validates :occurred_at, presence: true
  validates :event_type, inclusion: { in: EVENT_TYPES }

  # What prefills the search for the same person, taken from the subject rather
  # than from the key: `subject_key` folds the case, so a form filled from the
  # key would show `dupont` where the exchange said `Dupont`.
  def subject_criteria
    return {} if evidence_subject_key.blank?

    JSON.parse(evidence_subject.to_s).symbolize_keys.slice(*SUBJECT_FIELDS)
  end

  # Append-only: a trace that can be rewritten proves nothing.
  #
  # This covers what goes through a record — `save`, `update`, `update_column`,
  # `destroy` — and nothing else. `update_all` and `upsert_all` issue SQL
  # without instantiating anything, so they never reach here; the purge relies
  # on that, `delete_all` being how it erases what is out of term. Those paths
  # are closed by the engine instead, `DatabasePrivileges` refusing `UPDATE` on
  # this table to the role the traffic-serving processes connect with. Both
  # guarantees are wanted: this one fails early, in the application's own
  # language, where the other fails late, in `PG::InsufficientPrivilege`.
  def readonly? = persisted?
end
