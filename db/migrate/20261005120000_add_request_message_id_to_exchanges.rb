# What the gateway called the request France submitted, so that a notification
# naming that message finds its exchange. `AuditEvent#message_id` holds it too,
# but the journal is kept for article 17 and erased on its own term; the
# exchange must not depend on it to be found.
class AddRequestMessageIdToExchanges < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_column :exchanges, :request_message_id, :string
    add_index :exchanges, :request_message_id, algorithm: :concurrently
  end
end
