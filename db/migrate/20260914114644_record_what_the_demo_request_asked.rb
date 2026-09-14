# What the journey named to the user before the request left: the evidence type
# asked for, the provider it was asked from — the two values requirement 27 of
# chapter 1 §2 makes the confirmation page show — and the title the procedure
# stood under. The procedure files them because a service provider knows what it
# asked for, and the tracking page says it again without putting the directory
# queries back on a page made to be reloaded.
class RecordWhatTheDemoRequestAsked < ActiveRecord::Migration[8.1]
  def change
    add_column :demo_requests, :evidence_type_name, :string
    add_column :demo_requests, :procedure_name, :string
    add_column :demo_requests, :provider_name, :string
  end
end
