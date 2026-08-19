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

  validates :occurred_at, presence: true
  validates :event_type, inclusion: { in: EVENT_TYPES }

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
