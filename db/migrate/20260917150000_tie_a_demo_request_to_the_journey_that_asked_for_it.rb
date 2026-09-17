# This register is what a zone of the documents page reads its own request back
# from, so each row says which journey opened it and which requirement it was
# opened under. A click writes a row and nothing else, so two clicks made before
# either answer returns file two independent rows.
#
# The table is emptied so both columns can be what they are rather than nullable
# for convenience: nothing is in service, and a row naming no journey is one no
# session could ever follow. Walking the demonstration again rebuilds it.
class TieADemoRequestToTheJourneyThatAskedForIt < ActiveRecord::Migration[8.1]
  # The index is built concurrently, like the one on the exchange log: under a
  # lock it would hold up the delivery of a document for as long as it took.
  disable_ddl_transaction!

  # `strong_migrations` cannot see inside an `execute`, and refuses a column
  # added `null: false` to a table it must assume holds rows. This one holds
  # none by the line above, and nothing is in service: the demonstration is
  # walked by hand, the system is not homologated, and no request is in flight
  # while this runs.
  def up
    safety_assured do
      execute('DELETE FROM demo_requests')

      add_column :demo_requests, :journey_id, :string, null: false
      add_column :demo_requests, :requirement_uuid, :string, null: false
    end

    # What a zone reads its own request back by, beside the unique index on
    # `exchange_id` a delivery is placed against. Plain, and not unique: asking
    # again is « a new unique request » (chapter 4.4 §4.1), so one requirement of
    # one journey has as many rows as it has clicks.
    add_index :demo_requests, %i[journey_id requirement_uuid], algorithm: :concurrently
  end

  def down
    remove_index :demo_requests, %i[journey_id requirement_uuid], algorithm: :concurrently
    remove_column :demo_requests, :requirement_uuid
    remove_column :demo_requests, :journey_id
  end
end
