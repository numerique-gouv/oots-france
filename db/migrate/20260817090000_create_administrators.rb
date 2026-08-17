class CreateAdministrators < ActiveRecord::Migration[8.1]
  def change
    create_table :administrators do |table|
      table.string :email, null: false
      table.string :password_digest, null: false

      table.timestamps
    end

    add_index :administrators, :email, unique: true
  end
end
