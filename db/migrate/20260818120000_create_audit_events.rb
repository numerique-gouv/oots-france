class CreateAuditEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :audit_events do |table|
      # The moment and the nature of what is recorded. The log is append-only:
      # no row is ever taken up again, hence no `updated_at`.
      table.datetime :occurred_at, null: false
      table.string :event_type, null: false
      table.string :ebms_action

      # The correlation identifiers chapter 4.8 enumerates. They are what makes
      # it possible to sew an exchange back together from scattered traces —
      # ours, the gateway's, the correspondent's.
      table.string :conversation_id
      table.string :exchange_id
      table.string :message_id
      table.string :request_id
      table.string :response_id

      # The two corners, with their identifier scheme: a bare SIRET designates
      # nobody outside France.
      table.string :requesting_authority_id
      table.string :requesting_authority_scheme
      table.string :providing_authority_id
      table.string :providing_authority_scheme

      # The French service provider that called our API. No chapter names it —
      # it stands on this side of the border — but without it there is no
      # knowing on whose behalf the exchange took place.
      table.string :evidence_requester_id

      table.string :procedure_code
      table.string :evidence_type_id

      # Personal data, encrypted at rest. `evidence_subject_key` deterministically
      # so, to stay queryable: article 17 exists so that what data about a given
      # person travelled can be answered.
      table.text :evidence_subject
      table.string :evidence_subject_key

      # The fingerprint of the evidence, never the evidence.
      table.string :evidence_digest
      table.string :mime_type

      table.string :edm_error_code
      table.text :detail

      table.datetime :created_at, null: false
    end

    add_index :audit_events, :conversation_id
    add_index :audit_events, :occurred_at
    add_index :audit_events, :evidence_subject_key
  end
end
