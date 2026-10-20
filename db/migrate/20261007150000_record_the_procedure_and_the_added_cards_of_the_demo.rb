# The procedure each request of the demonstration went out under, now that the
# walk plays the one the operator chose, and the cards the operator added to
# the documents page beyond those the Evidence Broker lists for it, in the order
# they were added.
#
# Nullable, with no backfill: nothing is in service, and every row already
# written belongs to a journey no session can open any more.
class RecordTheProcedureAndTheAddedCardsOfTheDemo < ActiveRecord::Migration[8.1]
  def change
    add_column :demo_requests, :procedure_code, :string
    add_column :demo_cards, :added_at, :datetime
  end
end
