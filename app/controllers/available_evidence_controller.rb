# The public page of available evidence: for a requirement chosen among those
# the production Evidence Broker publishes, what each country references for
# it. Read from a copy of the directories and never from them — chapter 3.7 §4,
# « Clients should limit unnecessary access » —, so opening it queries no
# directory; the names of the countries come from the cached code list.
class AvailableEvidenceController < ApplicationController
  include ChosenLanguage
  include RecognisesAdministrator

  helper_method :snapshot, :last_failure

  def index
    return unless snapshot

    @requirements = catalogue.requirements.reject(&:smoke_test?)
      .sort_by { |requirement| sort_key(requirement.display_name) }
    @publishing = @requirements.index_with { |requirement| catalogue.publishing_countries(requirement) }
    @country_names = country_names
    @country_choices = country_choices
  end

  def show
    raise ActiveRecord::RecordNotFound if snapshot.nil?

    requirement = catalogue.requirement(params[:requirement_id])
    raise ActiveRecord::RecordNotFound if requirement.nil? || requirement.smoke_test?

    @availability = RequirementAvailability.new(snapshot:, requirement:, country_names:)
  end

  private

  def snapshot = @snapshot ||= DirectorySnapshot.current

  def country_names = CodeListClient.new.country_names(lang: I18n.locale)

  # What the administrator alone reads beside the button.
  def last_failure = (DirectorySnapshot.last_failure if named_administrator?)

  def catalogue
    @catalogue ||= Directories::Catalogue.new(
      evidence_broker: EvidenceBrokerClient.new(query: Directories::RecordedQuery.new(snapshot)),
    )
  end

  def presentation_page? = true

  # The countries the cards name, as the list beside the search offers them.
  def country_choices
    @publishing.values.flatten.uniq.sort_by { |code| sort_key(@country_names[code] || code) }
      .map { |code| [CountryTagComponent.label(code, @country_names[code]), code] }
  end

  def sort_key(name) = ActiveSupport::Inflector.transliterate(name.to_s).downcase
end
