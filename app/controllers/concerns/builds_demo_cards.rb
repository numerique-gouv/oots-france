# One card of the documents page, built the same way whether the page renders it
# among the others or the choice of a country answers it alone: what a card
# offers must not depend on which of the two drew it.
module BuildsDemoCards
  extend ActiveSupport::Concern

  # The country a card stands in, and whether it may change it, come from there.
  include HoldsDemoCountries

  private

  # A provider whose gateway does not announce the line of the journey offers
  # no button: requirement 27 of chapter 1 §2 has the user told « before any
  # request is made », and the contract would refuse the request anyway
  # (chapter 4.5.1 §2.2).
  def requirement_card(wording)
    spoken = spoken?(wording)

    DemoRequirementCardComponent.new(
      wording:, country_code: wording.country_code, country_name: country_name(wording.country_code),
      countries: country_options(wording), zone: (demo_request_zone(wording) if wording.nameable? && spoken),
      unspoken: (demo_specification unless spoken),
    )
  end

  def spoken?(wording) = wording.access_point.nil? || wording.access_point.speaks?(demo_specification)

  # The button of one card, in whatever state the register puts it: a reload is
  # not a new request, so a requirement already under way opens on its waiting
  # rather than on a button that would start a second.
  def demo_request_zone(wording)
    DemoRequestZoneComponent.new(outcome: demo_outcome_for(wording.requirement_uuid),
      requirement_uuid: wording.requirement_uuid)
  end

  # In English, like the page. A code list that says nothing leaves the name
  # blank, and the box then shows the code alone. The code and the name travel
  # apart, and not the box around them: a ViewComponent instance is single-use,
  # and a card names the country more than once.
  def country_name(code) = country_names[code]

  # What a card offers to pick from, read as a country reads everywhere in the
  # console and sorted by the name it shows. `nil` on a card that stays in the
  # country of the request it follows, which offers no choice.
  def country_options(wording)
    return if held_country(wording.requirement_uuid)

    @country_options ||= HoldsDemoCountries::OFFERED
      .map { |code| [CountryTagComponent.label(code, country_name(code)), code] }
      .sort_by { |(_, code)| country_name(code).presence || code }
  end

  def country_names = @country_names ||= code_lists.country_names(lang: :en)

  # One client per request, as `Admin::CommonServices::BaseController` keeps one
  # for its section: the lists it answers are the same on every call, and a
  # second instance would fetch them again.
  def code_lists = @code_lists ||= CodeListClient.new
end
