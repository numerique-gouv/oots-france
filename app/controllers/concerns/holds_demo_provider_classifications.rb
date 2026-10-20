# The user's answers to the questions the Data Service Directory asks on a card
# of the documents page — `DSD:ERR:0005`, chapter 3.1.4 §4.4.3.3 — by evidence
# type UUID, then by question UUID: the directory is asked once per type, and
# each type of a combination asks its own.
#
# The sibling of `HoldsDemoEvidenceTypeLists`, and held line by line: a line
# follows the answers of its request while that request is under way or its
# document is in hand; otherwise the last answers given on it during this
# journey, which the row of `Demo::Card` holds; otherwise none, and the line
# asks. Choosing a country or a combination writes the row again from a
# resolution made without answers, which undoes them.
module HoldsDemoProviderClassifications
  extend ActiveSupport::Concern

  include HoldsDemoEvidenceTypeLists

  private

  def card_provider_classifications(requirement_uuid)
    chosen_provider_classifications.fetch(requirement_uuid, {}).merge(held_provider_classifications(requirement_uuid))
  end

  # The answers of every card that has some, which is what the page resolves
  # each on.
  def all_card_provider_classifications
    card_countries.keys.index_with { |uuid| card_provider_classifications(uuid) }.compact_blank
  end

  # The answers of each request under way or whose document is in hand, by
  # evidence type UUID.
  def held_provider_classifications(requirement_uuid)
    holding_requests(requirement_uuid).transform_values { |request| request.provider_classifications.to_h }.compact_blank
  end

  def chosen_provider_classifications
    @chosen_provider_classifications ||= ::Demo::Card.provider_classifications(journey.id)
  end
end
