class AddEvidenceMimeTypeToDemoRequests < ActiveRecord::Migration[8.1]
  def change
    add_column :demo_requests, :evidence_mime_type, :string
  end
end
