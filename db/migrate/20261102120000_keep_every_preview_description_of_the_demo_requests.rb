# Every variant of the preview description the contract published, kept with
# the link: the departure page chooses one at each display, in the language the
# reader chose then (chapter 4.9 §5), and the contract publishes them only
# while the preview awaits its confirmation.
#
# No backfill, and no step in between: nothing is in service, and no request of
# the demonstration is in flight while this runs.
class KeepEveryPreviewDescriptionOfTheDemoRequests < ActiveRecord::Migration[8.1]
  def change
    safety_assured do
      change_table :demo_requests, bulk: true do |t|
        t.remove :preview_description, type: :text
        t.remove :preview_description_language, type: :string
        t.jsonb :preview_descriptions, default: [], null: false
      end
    end
  end
end
