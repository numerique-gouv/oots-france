class AddDeliveringAtToConversations < ActiveRecord::Migration[8.1]
  def change
    # Chapter 4.4: a portal must not process a response « to which it already
    # received a response ». The guard that applies the rule reads the exchange
    # into memory, and handing the evidence over — a POST, irreversible —
    # precedes every write: two concurrent responses pass it together. This
    # column carries the reservation only one of them takes.
    add_column :conversations, :delivering_at, :datetime
  end
end
