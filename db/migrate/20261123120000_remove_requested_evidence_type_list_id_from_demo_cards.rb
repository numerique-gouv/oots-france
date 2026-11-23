# Nothing reads this column: the types of a combination are asked for one after
# the other, each by its own button, and no click names a whole combination.
#
# `safety_assured` because `strong_migrations` wants the column ignored by the
# model first, so that a process started before the migration does not write
# it. Nothing is in service, and `make update` restarts every process after
# migrating.
class RemoveRequestedEvidenceTypeListIdFromDemoCards < ActiveRecord::Migration[8.1]
  def change
    safety_assured { remove_column :demo_cards, :requested_evidence_type_list_id, :string }
  end
end
