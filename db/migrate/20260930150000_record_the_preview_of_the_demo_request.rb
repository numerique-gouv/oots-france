# What the confirmation of a preview handed the demonstration procedure — the
# link to present, with its verb and its body, and the description it presents
# it under — and the instant the user came back by the return address. Chapter
# 4.9 §5 has the portal build its departure page from these, and the answer to
# the confirmation is the only place the link is ever given.
class RecordThePreviewOfTheDemoRequest < ActiveRecord::Migration[8.1]
  # `strong_migrations` cannot see inside a `change_table`. What happens there
  # is six nullable columns and nothing else, which no table has to be rewritten
  # or locked for long to receive.
  def change
    safety_assured do
      change_table :demo_requests, bulk: true do |t|
        t.text :preview_address
        t.string :preview_method
        t.text :preview_body
        t.text :preview_description
        t.string :preview_description_language
        t.datetime :returned_at
      end
    end
  end
end
