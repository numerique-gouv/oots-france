class AddStudentStatusLookupToPreviewSessions < ActiveRecord::Migration[8.1]
  def change
    change_table :preview_sessions, bulk: true do |t|
      t.boolean :lookup_pending, default: false, null: false
      t.string :unobtainable
    end
  end
end
