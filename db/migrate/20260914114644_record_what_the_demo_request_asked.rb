# What the journey named to the user before the request left: the evidence type
# asked for, the provider it was asked from — the two values requirement 27 of
# chapter 1 §2 makes the confirmation page show — and the title the procedure
# stood under. The procedure files them because a service provider knows what it
# asked for, and the tracking page says it again without putting the directory
# queries back on a page made to be reloaded.
#
# The language beside each name, because the page that says them again is
# written in English and the directories publish what they publish: a French
# name read as English is what RGAA 8.7 exists to prevent, and nothing else on
# the page could recover it.
class RecordWhatTheDemoRequestAsked < ActiveRecord::Migration[8.1]
  def change
    add_column :demo_requests, :evidence_type_name, :string
    add_column :demo_requests, :evidence_type_language, :string
    add_column :demo_requests, :procedure_name, :string
    add_column :demo_requests, :procedure_language, :string
    add_column :demo_requests, :provider_name, :string
    add_column :demo_requests, :provider_language, :string
  end
end
