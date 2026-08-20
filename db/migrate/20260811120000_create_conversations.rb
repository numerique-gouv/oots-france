class CreateConversations < ActiveRecord::Migration[8.1]
  def change
    create_table :conversations do |table|
      # The identifier that travels in the ebMS header and brings a response
      # together with the request that caused it. It is the only handle: the
      # gateway returns nothing else that makes the link.
      table.string :conversation_id, null: false
      table.string :status, null: false, default: 'pending'

      # What it takes to resume the exchange and find who to answer. No personal
      # data here: the beneficiary lives in the token the requester supplies, and
      # need not be kept for the conversation to advance.
      table.string :procedure_code, null: false
      table.string :country_code, null: false
      table.string :evidence_requester_id, null: false

      # The foreign provider's preview space, where it requires the user to go
      # there before it will deliver the evidence.
      table.text :preview_location

      table.string :edm_error_code
      table.text :error_description

      table.datetime :settled_at

      table.timestamps
    end

    add_index :conversations, :conversation_id, unique: true
    add_index :conversations, :status
  end
end
