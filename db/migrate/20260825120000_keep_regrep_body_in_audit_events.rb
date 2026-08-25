# Chapter 4.8 asks both its tables for « MIME type and full content of first
# MIME part » — the RegRep metadata document, in both directions. Nothing held
# it: Domibus erases the payload as `retrieveMessage` returns, its PMode
# carrying `retention_downloaded="0"`.
class KeepRegrepBodyInAuditEvents < ActiveRecord::Migration[8.1]
  def change
    # `strong_migrations` refuses a rename because a deployment mid-rollout
    # would have code reading the old name and code reading the new one. This
    # deployment has no such window: the requester interface is behind
    # `Settings.evidence_request_enabled?` and the system is not homologated, so
    # no exchange is in flight while this runs. One method writes the column and
    # one page reads it.
    safety_assured do
      # It has only ever held the type of the evidence — the *second* MIME part
      # — and the unqualified name now belongs to the first.
      rename_column :audit_events, :mime_type, :evidence_mime_type
    end

    # What the sender declared on the first part, and not a constant: on the way
    # in it is what the correspondent announced, and the discrepancy with what
    # chapter 4.7.1 fixes is exactly what an auditor comes to see.
    add_column :audit_events, :regrep_mime_type, :string
    add_column :audit_events, :regrep_body, :text
  end
end
