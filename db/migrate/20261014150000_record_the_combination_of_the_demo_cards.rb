# The combination each card of the demonstration names — the `sdg:EvidenceTypeList`
# the user chose, chapter 3.2.2 §2.3 — and, in `evidence_types`, one line per
# evidence type in it, each keeping what that type's request will send: its
# provider and the answers it was resolved on. Each request keeps the
# combination it came from.
#
# `requested_evidence_type_list_id` is the combination a click on « Request the
# documents » was made for, which a refusal of the contract leaves with no
# request to show it by.
#
# No backfill, and no step in between: nothing is in service, every row already
# written belongs to a journey no session can open any more, and no request of
# the demonstration is in flight while this runs.
class RecordTheCombinationOfTheDemoCards < ActiveRecord::Migration[8.1]
  def change
    safety_assured { record_the_combination }
    add_column :demo_requests, :evidence_type_list_id, :string
  end

  private

  def record_the_combination
    change_table :demo_cards, bulk: true do |t|
      t.remove :evidence_type_id, type: :string
      t.remove :evidence_type_name, type: :string
      t.remove :evidence_type_language, type: :string
      t.remove :provider_name, type: :string
      t.remove :provider_language, type: :string
      t.remove :provider_classifications, type: :jsonb, default: {}, null: false
      t.string :evidence_type_list_id
      t.jsonb :evidence_types, default: [], null: false
      t.string :requested_evidence_type_list_id
    end
  end
end
