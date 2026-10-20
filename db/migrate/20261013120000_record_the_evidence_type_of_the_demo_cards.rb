# The identifier of the evidence type each card of the demonstration names, and
# each of its requests asked for: the user chooses it on the card where the
# country publishes several, and the request carries it in
# `idTypeJustificatif`.
#
# Nullable, with no backfill: nothing is in service, and every row already
# written belongs to a journey no session can open any more.
class RecordTheEvidenceTypeOfTheDemoCards < ActiveRecord::Migration[8.1]
  def change
    add_column :demo_cards, :evidence_type_id, :string
    add_column :demo_requests, :evidence_type_id, :string
  end
end
