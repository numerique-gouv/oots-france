class CreateDirectorySnapshots < ActiveRecord::Migration[8.1]
  def change
    create_table :directory_snapshots do |table|
      table.datetime :taken_at
      table.datetime :failed_at
      table.string :failure_code
      table.text :failure_detail

      table.timestamps
    end

    add_check_constraint :directory_snapshots, '(taken_at IS NULL) <> (failed_at IS NULL)',
      name: 'directory_snapshots_taken_or_failed'

    create_table :directory_snapshot_answers do |table|
      table.references :directory_snapshot, null: false, index: false, foreign_key: { on_delete: :cascade }
      table.string :key, null: false
      table.text :body, null: false
    end

    add_index :directory_snapshot_answers, %i[directory_snapshot_id key], unique: true,
      name: 'index_directory_snapshot_answers_on_snapshot_and_key'
  end
end
