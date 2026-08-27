# The two rows of chapter 4.8 nothing held. Both are correlation: one ties an
# attachment to the `rim:RepositoryItemRef` that names it, the other ties the
# legs of a preview loop together — 4.4 §4.3.2 calling it « an additional
# correlation of complex flows beside `ExchangeId` ».
#
# One migration and no backfill: nothing is in service, so no deployment holds
# rows these columns would have to be computed for.
class AddCorrelationFieldsToAuditEvents < ActiveRecord::Migration[8.1]
  def change
    # « For evidence content referenced using `rim:RepositoryItemRef` elements,
    # MIME type and MIME content identifier », starred for the requester, the
    # access points and the data service alike. The type had a column; the
    # content identifier — the `cid:` of the `eb:PartInfo` — had none.
    add_column :audit_events, :evidence_content_id, :string

    # Clear, like `exchanges.preview_location`: an address a correspondent
    # published carries no personal data of the subject.
    add_column :audit_events, :preview_location, :text
  end
end
