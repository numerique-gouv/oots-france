# The user's answers to the questions the Data Service Directory asks on a card
# of the documents page — `DSD:ERR:0005`, chapter 3.1.4 §4.4.3.3 — by question
# UUID.
#
# The sibling of `HoldsDemoEvidenceTypes`, and held the same way: a card follows
# the answers of the request it follows while that request is under way or its
# document is in hand; otherwise the last answers given on it during this
# journey, which its row of `Demo::Card` holds; otherwise none, and the card
# asks. Choosing a country or a type writes the row again from a resolution
# made without answers, which undoes them.
module HoldsDemoProviderClassifications
  extend ActiveSupport::Concern

  include HoldsDemoEvidenceTypes

  private

  def card_provider_classifications(requirement_uuid)
    held_provider_classifications(requirement_uuid) || chosen_provider_classifications.fetch(requirement_uuid, {})
  end

  # The answers of every card that has some, which is what the page resolves
  # each on.
  def all_card_provider_classifications
    card_countries.keys.index_with { |uuid| card_provider_classifications(uuid) }.compact_blank
  end

  # `nil` while the card is free to be answered.
  def held_provider_classifications(requirement_uuid)
    return unless held_country(requirement_uuid)

    demo_request_for(requirement_uuid)&.provider_classifications.to_h
  end

  def chosen_provider_classifications
    @chosen_provider_classifications ||= ::Demo::Card.provider_classifications(journey.id)
  end
end
