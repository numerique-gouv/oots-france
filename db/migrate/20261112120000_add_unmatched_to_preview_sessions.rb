class AddUnmatchedToPreviewSessions < ActiveRecord::Migration[8.1]
  def change
    add_column :preview_sessions, :unmatched, :boolean, default: false, null: false
  end
end
