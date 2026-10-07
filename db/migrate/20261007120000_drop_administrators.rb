class DropAdministrators < ActiveRecord::Migration[8.1]
  def change
    drop_table :administrators do |t|
      t.string :email, null: false
      t.string :password_digest, null: false
      t.timestamps
      t.index :email, unique: true
    end
  end
end
