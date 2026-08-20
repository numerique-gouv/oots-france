class AddCountryCodeToAuditEvents < ActiveRecord::Migration[8.1]
  def change
    add_column :audit_events, :country_code, :string
  end
end
