class SplitExchangeFromConversation < ActiveRecord::Migration[8.1]
  # `strong_migrations` refuses a rename because a deployment mid-rollout would
  # have code reading the old name and code reading the new one. This
  # deployment has no such window: the requester interface is behind
  # `Settings.evidence_request_enabled?` and the system is not homologated, so
  # no exchange is in flight while this runs.
  def change
    safety_assured do
      # Chapter 4.4 separates two identifiers this table held as one. The row is
      # an *exchange* — one evidence exchange, whose messages all reuse its
      # `ExchangeId` — and the conversation it belongs to identifies a single
      # authenticated user, which may span several exchanges of one session.
      rename_table :conversations, :exchanges

      add_column :exchanges, :exchange_id, :string

      # Copies into its own name the identifier this column already carries: one
      # request is one exchange, so every existing row's value is that
      # exchange's.
      up_only { execute 'UPDATE exchanges SET exchange_id = conversation_id' }

      change_column_null :exchanges, :exchange_id, false

      # The uniqueness moves: one row per exchange, several exchanges per
      # conversation.
      remove_index :exchanges, :conversation_id
      add_index :exchanges, :exchange_id, unique: true
      add_index :exchanges, :conversation_id
    end
  end
end
