# The combination of evidence types each card of the documents page names,
# where its country publishes several for the requirement — chapter 3.2.2 §2.3:
# « The user can select an 'Evidence Type List' amongst the ones proposed by the
# Evidence Broker. »
#
# The sibling of `HoldsDemoCountries`, and held the same way: a card follows the
# combination of the request it follows while that request is under way or its
# document is in hand; otherwise the last combination chosen on it during this
# journey, which its row of `Demo::Card` holds; otherwise none, and the user
# chooses. Choosing a country writes the row again from the resolution in that
# country, which names a combination only where it publishes a single one, so a
# combination is always one the country of the card publishes.
#
# By the list's `sdg:Identifier`, which chapter 3.2.4 §4.3.2 has every list
# carry once.
module HoldsDemoEvidenceTypeLists
  extend ActiveSupport::Concern

  include HoldsDemoCountries

  private

  def card_evidence_type_list(requirement_uuid)
    held_evidence_type_list(requirement_uuid) || chosen_evidence_type_lists[requirement_uuid]
  end

  # The combination of every card that has one, which is what the page
  # resolves each on.
  def card_evidence_type_lists
    card_countries.keys.index_with { |uuid| card_evidence_type_list(uuid) }.compact
  end

  # `nil` while the card is free to change combination.
  def held_evidence_type_list(requirement_uuid) = holding_request(requirement_uuid)&.evidence_type_list_id

  def chosen_evidence_type_lists = @chosen_evidence_type_lists ||= ::Demo::Card.evidence_type_lists(journey.id)
end
