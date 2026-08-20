class AddDirectionToConversations < ActiveRecord::Migration[8.1]
  # A received exchange gives a row too, so the three columns stop being
  # required: an outgoing exchange always knows them, where a request too
  # malformed to read names none of them — and that is precisely the exchange
  # an auditor needs to find. `Conversation` requires them of the outgoing
  # direction alone.
  def change
    add_column :conversations, :incoming, :boolean, default: false, null: false
    change_column_null :conversations, :country_code, true
    change_column_null :conversations, :procedure_code, true
    change_column_null :conversations, :evidence_requester_id, true
  end
end
