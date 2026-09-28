# The member state each card of the documents page resolves its requirement in,
# and the request of that card is addressed to — step 16 of chapter 1 §10.1:
# « The sample Portal asks the user to specify from which Member State the
# evidence is to be requested. »
#
# A card stands in the country of the request it follows while that request is
# under way or its document is in hand, whatever was chosen since; otherwise in
# the last country chosen on it during this journey; otherwise in the
# deployment's own. The choice is filed under the journey it was made in, so a
# new identification, which opens a new journey, starts every card afresh.
module HoldsDemoCountries
  extend ActiveSupport::Concern

  # Which request a card follows is read from the register, under the journey.
  include ReadsDemoRequest

  # The `OOTS_Country` code list, which chapter 3.2.4 §4.3 names as the source
  # of the optional parameters, without `EU`: not a state a user designates.
  OFFERED = (IdentifierScheme::OOTS_COUNTRIES - ['EU']).freeze

  private

  def offered_country?(code) = OFFERED.include?(code)

  def card_country(requirement_uuid)
    held_country(requirement_uuid) || chosen_countries[requirement_uuid] || Settings.common_services_country_code
  end

  # The country of every card this journey has either chosen one on or asked
  # something under, which is what the page resolves each in.
  def card_countries
    asked = ::Demo::Request.where(journey_id: journey.id).distinct.pluck(:requirement_uuid)

    (chosen_countries.keys | asked).index_with { |uuid| card_country(uuid) }
  end

  # `nil` while the card is free to change country.
  def held_country(requirement_uuid)
    demo_request_for(requirement_uuid)&.country_code if demo_outcome_for(requirement_uuid)&.holds_country?
  end

  def choose_country(requirement_uuid, code)
    session[:demo_countries] = { 'journey' => journey.id,
                                 'countries' => chosen_countries.merge(requirement_uuid => code) }
  end

  def chosen_countries
    stored = session[:demo_countries].to_h
    stored['journey'] == journey.id ? stored['countries'].to_h : {}
  end
end
