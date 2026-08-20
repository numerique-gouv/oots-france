class AddRequestIdToConversations < ActiveRecord::Migration[8.1]
  def change
    # Chapter 4.4 correlates a response to its request by this identifier, which
    # the repository read and never kept.
    add_column :conversations, :request_id, :string
  end
end
