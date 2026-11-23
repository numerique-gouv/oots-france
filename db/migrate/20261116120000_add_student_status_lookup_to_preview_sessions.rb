class AddStudentStatusLookupToPreviewSessions < ActiveRecord::Migration[8.1]
  # `strong_migrations` cannot see inside a `change_table`. What happens there
  # is a boolean with a constant default and a nullable string, which
  # PostgreSQL adds without rewriting the table.
  def change
    safety_assured do
      change_table :preview_sessions, bulk: true do |t|
        t.boolean :lookup_pending, default: false, null: false
        t.string :unobtainable
      end
    end
  end
end
