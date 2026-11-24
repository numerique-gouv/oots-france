class AddEbmsHeaderToAuditEvents < ActiveRecord::Migration[8.1]
  def change
    add_column :audit_events, :ebms_header, :text
  end
end
