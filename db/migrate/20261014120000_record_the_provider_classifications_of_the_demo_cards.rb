# The user's answers to the questions the Data Service Directory asks on a card
# of the demonstration — `DSD:ERR:0005`, chapter 3.1.4 §4.4.3.3 — by question
# UUID: what the card was resolved on, and what its request sent in
# `classificationFournisseur`.
class RecordTheProviderClassificationsOfTheDemoCards < ActiveRecord::Migration[8.1]
  def change
    add_column :demo_cards, :provider_classifications, :jsonb, default: {}, null: false
    add_column :demo_requests, :provider_classifications, :jsonb, default: {}, null: false
  end
end
