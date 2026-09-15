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
# Only one card carries the press for now. The contract a service provider calls
# names no requirement, and its server answers with the first that publishes
# evidence types, so a second button would send the same request under another
# name. Stub, tracked as OOTS-212.
#
# `zone` is where that press lives, and it is the one part of the card an answer
# replaces: the card itself says what the requirement is and who satisfies it,
# which no answer changes.
class DemoRequirementCardComponent < ViewComponent::Base
  def initialize(wording:, askable:, country_code:, country_name: nil, zone: nil)
    @wording = wording
    @askable = askable
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

  def askable? = @askable && nameable? && zone.present?

  delegate :nameable?, :published_nothing?, :evidence_type, :evidence_type_language, :provider,
    :provider_language, :requirement, :requirement_language, to: :wording

  private

  attr_reader :wording
end
