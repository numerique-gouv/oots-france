# One requirement of the procedure, as the documents page offers it: the
# evidence type that satisfies it, the provider holding that evidence, and the
# press that asks for it.
#
# The two names are what requirement 27 of chapter 1 §2 asks for word for word —
# « The user is provided with information about name of evidence provider and
# evidence type for confirmation, before any request is made » — so a card
# unable to name them offers nothing to press: the requirement is a condition of
# the request, not a decoration on it.
#
# `zone` is where the press lives, and it is the one part of the card an answer
# replaces: the card itself says what the requirement is and who satisfies it,
# which no answer changes. Every card that can name its two names carries one,
# and each follows its own request — chapter 4.4 §4.2.2 has « different basic
# flows … executed sequentially and/or in parallel », so no card waits on its
# neighbour. The address the browser re-asks is what tells them apart: it names
# this card's requirement.
class DemoRequirementCardComponent < ViewComponent::Base
  def initialize(wording:, country_code:, country_name: nil, zone: nil)
    @wording = wording
    @country_code = country_code
    @country_name = country_name
    @zone = zone
    super()
  end

  attr_reader :zone

  # The jurisdiction the evidence was sought in, which the card names twice: in
  # what satisfies the requirement, and in what stands there when nothing does.
  # A box of its own each time — a ViewComponent instance is single-use.
  def country_tag = CountryTagComponent.new(code: @country_code, name: @country_name)

  # The name alone, where the line above already shows the country in its box:
  # a second flag and a second code would say the same thing twice.
  def country_name = @country_name.presence || @country_code

  CLASSES = %w[fr-card fr-card--shadow fr-card--no-arrow requirement-card fr-col-12 fr-col-md-8 fr-mb-4w].freeze

  # A requirement nothing satisfies is a dead end of the procedure, and the card
  # says so by its ground as well as by its wording — never by the ground alone,
  # which RGAA 3.1 forbids.
  def css_classes = class_names(*CLASSES, 'requirement-card--unsatisfiable' => !nameable?)

  # The requirement names the card whatever the directories answered next:
  # one nobody serves is still one the procedure rests on.
  def titled? = requirement.present?

  def askable? = nameable? && zone.present?

  # The address this card's zone answers on, and the one the browser re-asks
  # while it waits. The UUID and not the whole identifier: it is what the
  # console and `DirectoryLookup` already pass between themselves, and a
  # Semantic Repository URL would have to be escaped into the query string of
  # every one of these.
  def zone_path = helpers.admin_demo_demande_path(exigence: requirement_uuid)

  delegate :nameable?, :published_nothing?, :evidence_type, :evidence_type_language, :provider,
    :provider_language, :requirement, :requirement_language, :requirement_uuid, to: :wording

  private

  attr_reader :wording
end
