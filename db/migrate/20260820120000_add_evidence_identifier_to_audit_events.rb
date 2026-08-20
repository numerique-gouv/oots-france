class AddEvidenceIdentifierToAuditEvents < ActiveRecord::Migration[8.1]
  def change
    # Chapter 4.8 names it for the response flow — « Evidence Identifier (for
    # evidence response) » — and takes it from the `Identifier` of the
    # `EvidenceMetadata` block.
    add_column :audit_events, :evidence_identifier, :string
  end
end
