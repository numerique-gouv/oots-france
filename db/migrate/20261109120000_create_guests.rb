class CreateGuests < ActiveRecord::Migration[8.1]
  def change
    create_table :guests do |table|
      table.string :email, null: false

      table.timestamps
    end

    add_index :guests, :email, unique: true
  end
end
