# The requirement the press named to the contract, beside the evidence type and
# the provider the same card named to the user. A procedure rests on several of
# them and the demonstration now asks for each separately, so a row saying which
# document was asked for no longer says which obligation it was asked under.
#
# The identifier is the one that went out in `idExigence` — the Semantic
# Repository URL entire — and the name is what the card stood under, with the
# language the directory published it in, like every other name this table
# keeps.
class RecordWhichRequirementTheDemoRequestAskedFor < ActiveRecord::Migration[8.1]
  def change
    add_column :demo_requests, :requirement_id, :string
    add_column :demo_requests, :requirement_name, :string
    add_column :demo_requests, :requirement_language, :string
  end
end
