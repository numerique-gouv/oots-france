# The member state the click addressed its request to, beside what the card
# named of it: the user now picks one per card (step 16 of chapter 1 §10.1), so
# a row naming the document and its provider no longer says in which country
# they were published. Nullable like the other names this table keeps; the
# model requires it of every row it writes.
class RecordWhichCountryTheDemoRequestAsked < ActiveRecord::Migration[8.1]
  def change
    add_column :demo_requests, :country_code, :string
  end
end
