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

  # What the canonical key of a natural person is built from, named here
  # because `NaturalPerson` carries more than it.
  SUBJECT_FIELDS = %i[family_name given_name date_of_birth].freeze

  # Its counterpart for the other subject chapter 4.5.1 allows. Both fields are
  # wanted to recognise an organisation, only the first composes the key:
  # `LegalPersonIdentifier` is 1..1 and the identifier eIDAS asserts, which the
  # slot's own cardinality and description carry — the rules only bound it,
  # `R-EDM-REQ-C049` demanding its presence and `R-EDM-REQ-C051` its form. So it
  # identifies on its own, while `LegalName` is what tells an organisation from
  # a natural person — one read off a response carries an eIDAS identifier too.
  #
  # The name stays out of the key because a correspondent rewrites it: the
  # provider answers with what its own base holds, « ETS DUPONT ET FILS » where
  # the request said « Établissements Dupont & Fils ». Keyed on the pair, one
  # subject would hold two keys, and the key exists precisely to gather the
  # lines of one subject.
  LEGAL_SUBJECT_FIELDS = %i[eidas_identifier legal_name].freeze

  # The mark that opens the organisation's form in the single column that holds
  # both, and that reserves the place of a third: chapter 4.8 names
  # `Representative` as a subject the journal may come to record. The natural
  # key carries no mark — what tells the forms apart is how many components were
  # joined, not what opens them.
  LEGAL_KEY_PREFIX = 'legal|'.freeze

  # The value the deterministic column is queried by, so that an auditor can
  # answer the question article 17 exists for: which data of this person
  # travelled? Case-folded, because two member states spell a name in two cases
  # and mean one person.
  #
  # It lives here rather than where it is written: a deterministic column can
  # only be searched by a value built exactly as it was stored, so whoever
  # searches has to build it the same way.
  def self.subject_key(family_name:, given_name:, date_of_birth:)
    join(family_name, given_name, date_of_birth)
  end

  # What makes the join injective, and with it the whole column: a `|` inside a
  # component takes a backslash, and a backslash doubles, so a bare `|` in a key
  # is always a separator and never a character someone was named with.
  #
  # It is what tells the two forms apart, the count of those separators being
  # the count of components — two for a natural person, one for an organisation.
  # R-EDM-REQ-C051 shapes an eIDAS identifier as `XX/YY/Z…Z` and constrains the
  # last segment to be non-blank and nothing more, so `FR/FR/AB|123456` is a
  # conformant identifier carrying a bare separator; and a subject read off a
  # response is not validated at all. Unescaped, such an identifier composed the
  # very key of a person — « Legal » being an ordinary French family name — and
  # one search then answered about her and about an organisation at once.
  def self.join(*components) = components.map { |component| escape(component) }.join('|').downcase

  def self.escape(component) = component.to_s.gsub(/[\\|]/) { |character| "\\#{character}" }

  private_class_method :join, :escape

  # The same, for an organisation. Case-folded for the same reason: two member
  # states write an identifier in two cases and mean one organisation.
  def self.legal_subject_key(eidas_identifier:)
    "#{LEGAL_KEY_PREFIX}#{join(eidas_identifier)}"
  end

  # Whether a described subject carries a whole identity of that form. Asked
  # both by the key and by the criteria that prefill a search, which have to
  # agree: criteria naming the other identity would search a key the journal
  # never wrote.
  #
  # A field present but empty counts as absent, and the distinction is not
  # academic: `EvidenceResponseParser` reads the wire without validating, and
  # `text_at` renders `<sdg:LegalPersonIdentifier/>` — present, empty — as `""`,
  # which `attributes.compact` keeps. Counted as carried, it composed the key
  # `legal|` for every organisation a correspondent answered that way, gathering
  # unrelated subjects under one value in the column that exists to tell them
  # apart. The natural form has the same hole, narrower only because three
  # fields have to be empty at once rather than one.
  def self.carries?(described, fields)
    held = described.symbolize_keys.slice(*fields)

    held.size == fields.size && held.each_value.all?(&:present?)
  end

  # The two columns a subject is written as, built in one place because they
  # have to agree: the deterministic one is only searchable by a value composed
  # exactly as it was stored.
  def self.subject(person)
    return {} if person.nil?

    described = person.attributes.compact

    { evidence_subject: described.to_json, evidence_subject_key: canonical_key(described) }
  end

  # One of the two forms, or none. `legal_name` is what tells them apart, and no
  # natural person carries one: a subject read off a response carries an eIDAS
  # identifier as well as the triplet, so the identifier alone would have filed
  # a person as an organisation. Wanting the pair closes that; the order the two
  # are tried in only settles a hash carrying both whole, which neither
  # `NaturalPerson` nor `LegalPerson` can produce.
  #
  # Decided on the fields and not on the class of what is passed, because how
  # the key is composed belongs to the journal and not to the subject: a value
  # object serves the templates and the builders too, where a column of this
  # table means nothing.
  #
  # A subject France composed itself always carries one of the two whole, every
  # route that builds one validating it first — `BeneficiaryToken` and
  # `EvidenceRequestParser` each hand over an identity their own class has
  # already refused to leave incomplete. One read off a foreign response does
  # not —
  # `EvidenceResponseParser#evidence_subject` reads without validating, so a
  # provider answering short of a field loses the key silently. That is the
  # price of the trace: refusing the response would have cost the exchange, and
  # `evidence_subject` still holds everything that was read.
  def self.canonical_key(described)
    fields = described.symbolize_keys

    return subject_key(**fields.slice(*SUBJECT_FIELDS)) if carries?(fields, SUBJECT_FIELDS)

    legal_subject_key(eidas_identifier: fields[:eidas_identifier]) if carries?(fields, LEGAL_SUBJECT_FIELDS)
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

  # The subject read back as it was written: `self.subject` composes the column
  # with `to_json`, so a `JSON.parse` is what undoes it, and the two belong
  # together on whoever owns the column. It restores at the same time what the
  # encoder escaped — ActiveSupport writes `&`, `<` and `>` as the JSON escapes
  # `\u0026`, `\u003c` and `\u003e`, leaving the non-ASCII alone, which is why a
  # page rendering the raw column showed `\u0026` where a company name had an
  # ampersand, and `Établissements` whole.
  #
  # No rescue: the column has a single writer, and a value it could not parse
  # would be a defect worth failing on rather than a cell quietly left blank.
  def described_subject
    return {} if evidence_subject.to_s.empty?

    JSON.parse(evidence_subject)
  end

  # What prefills the search for the same subject, taken from the subject rather
  # than from the key: the key folds the case, so a form filled from it would
  # show `dupont` where the exchange said `Dupont`.
  #
  # The organisation is named by the criterion the form submits and not by the
  # field the subject holds it under: `SubjectSearch` asks for a
  # `legal_person_identifier`, chapter 4.5.1's own name for it, so that the two
  # forms of the page cannot be filled from one address.
  def subject_criteria
    described = described_subject.symbolize_keys
    return described.slice(*SUBJECT_FIELDS) if self.class.carries?(described, SUBJECT_FIELDS)
    return {} unless self.class.carries?(described, LEGAL_SUBJECT_FIELDS)

    { legal_person_identifier: described[:eidas_identifier] }
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
