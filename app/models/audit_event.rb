# One line of the exchange log chapter 4.8 requires, and that article 17 of the
# implementing regulation says must survive twelve months.
#
# Distinct from `Conversation`, which holds the current state of an exchange and
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
  EVENT_TYPES = %w[
    request_sent request_refused response_received error_received evidence_delivered
    request_received response_sent error_sent
  ].freeze

  encrypts :evidence_subject
  encrypts :evidence_subject_key, deterministic: true

  # What the canonical key is built from, named here because `NaturalPerson`
  # carries more than it.
  SUBJECT_FIELDS = %i[family_name given_name date_of_birth].freeze

  # The value the deterministic column is queried by. Case-folded, because two
  # member states spell a name in two cases and mean one person.
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

    {
      evidence_subject: person.attributes.compact.to_json,
      evidence_subject_key: subject_key(**person.attributes.symbolize_keys.slice(*SUBJECT_FIELDS)),
    }
  end

  # Which end of the gateway a message went through. Two events are no ebMS
  # message at all — a refusal pronounced before the gateway was called, and the
  # handing of the evidence to the French requester — and neither list holds
  # them. The pages read the type and the country as they are recorded, and draw
  # their own conclusion.
  SENT_BY_FRANCE = %w[request_sent response_sent error_sent].freeze
  RECEIVED_BY_FRANCE = %w[request_received response_received error_received].freeze

  # Le pendant du `has_many` de `Conversation`, joint par l'identifiant ebMS.
  # `optional`, et sans contrainte en base : un refus prononcé avant qu'aucun
  # échange soit ouvert n'en nomme aucun, et une réponse peut en nommer un que la
  # France n'a jamais ouvert.
  belongs_to :conversation, primary_key: :conversation_id,
    optional: true, inverse_of: :audit_events

  scope :about_subject, ->(key) { where(evidence_subject_key: key).order(occurred_at: :desc) }

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
  # on that, `delete_all` being how it erases what is out of term. Closing those
  # too takes a database role without `UPDATE`, which a migration cannot grant
  # itself, PostgreSQL letting a table's owner override its own revocations.
  def readonly? = persisted?
end
