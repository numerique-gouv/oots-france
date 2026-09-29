# The line the click asked its request in, which the journey chose on the first
# screen of the demonstration. Nullable like the country beside it; the model
# requires it of every row it writes.
class RecordWhichLineTheDemoRequestAsked < ActiveRecord::Migration[8.1]
  def change
    add_column :demo_requests, :specification, :string
  end
end
