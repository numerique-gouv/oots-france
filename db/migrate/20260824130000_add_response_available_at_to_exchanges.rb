class AddResponseAvailableAtToExchanges < ActiveRecord::Migration[8.1]
  def change
    # Chapter 4.5.2: a correspondent that cannot serve the evidence yet answers
    # `Unavailable` and names the date by which it will be. What it said, and
    # not what this deployment computes — no index, the status one already
    # covering the rows a sweep reads.
    add_column :exchanges, :response_available_at, :datetime
  end
end
