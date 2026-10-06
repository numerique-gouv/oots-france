# The last connectivity test France ran towards each party of the PMode, one row
# per party. Kept here because the gateway erases its own history of test
# messages whenever its console tests the same party.
class CreateConnectivityTests < ActiveRecord::Migration[8.1]
  def change
    create_table :connectivity_tests do |t|
      %i[party_name party_identifier party_identifier_type].each { |name| t.string name, null: false }
      t.string :outcome, null: false, default: 'pending'
      t.datetime :requested_at, null: false
      t.string :message_id
      t.string :error_code
      t.text :error_detail
      t.text :submission_refusal
      t.datetime :verdict_read_at
      t.timestamps
    end

    add_index :connectivity_tests, :party_name, unique: true
  end
end
