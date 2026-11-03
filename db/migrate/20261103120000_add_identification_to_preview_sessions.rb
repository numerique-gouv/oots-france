class AddIdentificationToPreviewSessions < ActiveRecord::Migration[8.1]
  def change
    add_column :preview_sessions, :identification, :string
  end
end
