class AddEbmsSentAtToExchanges < ActiveRecord::Migration[8.1]
  def change
    # The instant the sending gateway stamped — see `Exchange` for why a
    # received exchange's timeout is counted from it and not from `created_at`.
    #
    # Nullable and left empty on the rows already written: an exchange opened
    # before the column carries no such instant, and one destroyed with its
    # message — `retention_downloaded="0"` erases it on retrieval — cannot be
    # reconstituted. No index, the status one already covering the rows the
    # sweep reads.
    add_column :exchanges, :ebms_sent_at, :datetime
  end
end
