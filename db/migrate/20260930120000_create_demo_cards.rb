# What each card of the demonstration's documents page names, and the member
# state it stands in, one row per card of a journey. Kept out of the session,
# which the cookie store bounds at four kibibytes and which already carries the
# identity: one card more would overflow it. Nothing here identifies the user.
class CreateDemoCards < ActiveRecord::Migration[8.1]
  def change
    create_table :demo_cards do |t|
      t.string :journey_id, null: false
      t.string :requirement_uuid, null: false
      t.string :country_code, null: false
      %i[evidence_type_name evidence_type_language provider_name provider_language
         requirement_id requirement_name requirement_language].each { |name| t.string name }
      t.timestamps
    end

    add_index :demo_cards, %i[journey_id requirement_uuid], unique: true
  end
end
