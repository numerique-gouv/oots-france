class IndexAuditEventsOnExchangeId < ActiveRecord::Migration[8.1]
  # The log is written on the path of an incoming message: building the index
  # under a lock would hold up arrivals for as long as it took.
  disable_ddl_transaction!

  def change
    # The log of one exchange is joined by this column: a conversation covers
    # several exchanges, so only this one names a single exchange. Plain, and
    # not unique: an exchange leaves as many rows as it has steps.
    add_index :audit_events, :exchange_id, algorithm: :concurrently
  end
end
