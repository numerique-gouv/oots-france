# Dropped and recreated rather than altered: an account a deployment created
# with a password must not become a nomination by losing its digest.
class ReplaceAdministratorAccountsWithNamedAgents < ActiveRecord::Migration[8.1]
  def change
    drop_table :administrators do |t|
      t.string :email, null: false
      t.string :password_digest, null: false
      t.timestamps
      t.index :email, unique: true
    end

    create_table :administrators do |t|
      t.string :email, null: false
      t.timestamps
      t.index :email, unique: true
    end
  end
end
