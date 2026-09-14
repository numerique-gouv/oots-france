# What the home page of the demonstration lists under its procedure: the
# requirements the Evidence Broker publishes for it in France's jurisdiction
# (chapter 3.2.4), which is the first step of the chain a request walks.
#
# English first, where the console reads French first: this page is the portal,
# and its reader is a user of another Member State. A requirement the directory
# named in no language at all is left out — a bullet with no text reads as a
# line the page failed to render.
class DemoRequirements
  LANGUAGES = %w[EN FR].freeze

  def initialize(requirements)
    @requirements = Array(requirements)
  end

  delegate :any?, to: :named

  # Each wording with the language it is written in, which the page declares so
  # that a screen reader does not pronounce English as French (RGAA 8.7).
  def each(&) = named.each(&)

  private

  def named
    @named ||= @requirements.filter_map do |requirement|
      label = requirement.label(languages: LANGUAGES)

      [label, requirement.label_language(languages: LANGUAGES)] if label.present?
    end
  end
end
