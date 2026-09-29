# What an outgoing exchange keeps between the two round trips of chapter 4.9:
# what the second request repeats of the first apart from its subject, what the
# correspondent's exception said of the preview, and the return address France
# opens once the portal has confirmed. None of it is personal data — the
# subject is given again by the portal at confirmation.
class AddSecondExchangeToExchanges < ActiveRecord::Migration[8.1]
  # Exchanges are written on the path of every request and every arrival:
  # building the index under a lock would hold both up.
  disable_ddl_transaction!

  def change
    add_column :exchanges, :request_basis, :jsonb
    add_column :exchanges, :preview_descriptions, :jsonb
    add_column :exchanges, :preview_method, :string
    add_column :exchanges, :return_token, :string
    add_column :exchanges, :resume_location, :text
    add_column :exchanges, :preview_confirmed_at, :datetime

    add_index :exchanges, :return_token, unique: true, algorithm: :concurrently
  end
end
