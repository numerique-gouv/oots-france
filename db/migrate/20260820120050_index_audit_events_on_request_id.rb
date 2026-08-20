class IndexAuditEventsOnRequestId < ActiveRecord::Migration[8.1]
  # The log is written on the path of an incoming message: building the index
  # under a lock would hold up arrivals for as long as it took.
  disable_ddl_transaction!

  def change
    # Plain, and not unique. The row of a received request is written before the
    # replay chapter 4.4 has refused is detected, so a constraint would fire at
    # write time, out of reach of the code that has to build the refusal, and
    # the correspondent would get nothing where they used to get an answer. The
    # index only makes the search for that replay an indexed one.
    add_index :audit_events, :request_id, algorithm: :concurrently
  end
end
