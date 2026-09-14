# What the home page of the demonstration says of its procedure: the title it
# stands under, and the requirements it rests on.
#
# Both come from the same Evidence Broker answer — the requirements it publishes
# for the procedure in France's jurisdiction (chapter 3.2.4), which is the first
# step of the chain a request walks. The title is the one **France itself
# declared**, nested in that answer as a `ReferenceFramework`, and not the SDG
# title the code list publishes: a member state names its own procedure, and
# that name is what its portal would show. The code list is the fallback, for a
# directory that says nothing.
#
# English first, where the console reads French first: this page is the portal,
# and its reader is a user of another Member State.
class DemoProcedureWording
  LANGUAGES = %w[EN FR].freeze

  def initialize(code:, requirements:, published_name: nil)
    @code = code
    @requirements = Array(requirements)
    @published_name = published_name
  end

  attr_reader :code

  # The jurisdiction the procedure belongs to, which is the one its
  # requirements were asked in: a procedure is a member state's, and the flag
  # says whose before the code says which.
  def country_flag = CountryTagComponent.flag(Settings.common_services_country_code)

  # Nothing when neither source answered, and the page then stands under the
  # wording below rather than under a directory's.
  def title = declared_title.presence || @published_name

  # The language the title is written in, which the page declares so that a
  # screen reader does not pronounce English as French (RGAA 8.7).
  def title_language
    return declaration.label_language(languages: LANGUAGES) if declared_title.present?

    'en' if @published_name.present?
  end

  # Our own words, and the only part of the heading no directory published.
  def untitled = I18n.t(ProcedureComponent::NO_LABEL)

  def requirements_named = @requirements_named ||= named(@requirements)

  private

  def declared_title = declaration&.label(languages: LANGUAGES)

  # France declares the same code more than once, under titles of its own; the
  # page stands under the first the directory lists, which is the directory's
  # order and not chance.
  def declaration
    return @declaration if defined?(@declaration)

    @declaration = @requirements.flat_map(&:reference_frameworks)
      .find { |declared| declared.procedure_code == @code && declared.country == Settings.common_services_country_code }
  end

  # A requirement the directory named in no language at all is left out — a
  # bullet with no text reads as a line the page failed to render.
  def named(requirements)
    requirements.filter_map do |requirement|
      label = requirement.label(languages: LANGUAGES)

      [label, requirement.label_language(languages: LANGUAGES)] if label.present?
    end
  end
end
