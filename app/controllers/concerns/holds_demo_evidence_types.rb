# The evidence type each card of the documents page names, where its country
# publishes several for the requirement — requirement 26 of chapter 1 §2:
# « Evidence requesters shall give users the possibility to select and request
# the types of evidence. »
#
# The sibling of `HoldsDemoCountries`, and held the same way: a card follows the
# type of the request it follows while that request is under way or its
# document is in hand; otherwise the last type chosen on it during this
# journey, which its row of `Demo::Card` holds; otherwise none, and the user
# chooses. Choosing a country writes the row again from the resolution in that
# country, which names a type only where it publishes a single one, so a type
# is always one the country of the card publishes.
#
# By UUID, the last segment of the identifier, which is what the console and
# `DirectoryLookup` pass between themselves; the row keeps the identifier
# whole, which is what the request sends.
module HoldsDemoEvidenceTypes
  extend ActiveSupport::Concern

  include HoldsDemoCountries

  private

  def card_evidence_type(requirement_uuid)
    held_evidence_type(requirement_uuid) || chosen_evidence_types[requirement_uuid]
  end

  # The type of every card that has one, which is what the page resolves each on.
  def card_evidence_types
    card_countries.keys.index_with { |uuid| card_evidence_type(uuid) }.compact
  end

  # `nil` while the card is free to change type.
  def held_evidence_type(requirement_uuid)
    return unless held_country(requirement_uuid)

    uuid_of(demo_request_for(requirement_uuid)&.evidence_type_id)
  end

  def chosen_evidence_types
    @chosen_evidence_types ||= ::Demo::Card.evidence_types(journey.id).transform_values { |id| uuid_of(id) }.compact
  end

  def uuid_of(identifier) = (EvidenceType.new(id: identifier).uuid if identifier)
end
