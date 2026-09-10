# What the demonstration procedure keeps of the requests it made, so that an
# evidence delivered later can be placed on the one that asked for it.
#
# **It holds the evidence in clear, and this table alone may.** The document the
# demonstration ever receives is `assets/drapeau.pdf`, the sample France answers
# `T1` with; the identities that ask for it are fabricated by a fake
# FranceConnect+; and the only screen serving it is behind the operator's login.
# None of the three holds of a real portal, and none of them may be assumed by
# whoever reads this table as a model: a portal storing genuine evidence owes it
# the treatment `AuditEvent` gives the log of article 17, which stays what it is.
#
# No identity column, for the same reason: the exchange carries the beneficiary,
# and a second place to hold one would be a second place to purge the day these
# identities stop being invented.
class CreateDemoRequests < ActiveRecord::Migration[8.1]
  def change
    create_table :demo_requests do |t|
      # The two identifiers of chapter 4.4, as the `202` handed them back: the
      # exchange names this request, the conversation names the user and their
      # session. Both are checked before a delivery is filed here.
      t.string :exchange_id, null: false
      t.string :conversation_id, null: false

      t.binary :evidence
      t.string :evidence_digest
      t.datetime :evidence_received_at

      t.timestamps
    end

    # Unique: a delivery is placed by this value, and two rows carrying it would
    # make « the request that asked for this » a question with two answers.
    add_index :demo_requests, :exchange_id, unique: true
  end
end
