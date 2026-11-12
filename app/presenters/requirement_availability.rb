# What a copy of the production directories says of one requirement, country
# by country: the evidence types the Evidence Broker publishes for it, and for
# each what the Data Service Directory answered in that country — its data
# services, or its refusal.
#
# Read from the copy alone, through the parsers that read the directories live,
# so a refusal is replayed exactly as it was answered.
class RequirementAvailability
  # `DSD:ERR:0005` asks the user a question before naming the provider —
  # chapter 3.1.4 §4.2.4, « This error code always indicates that extra user
  # input is required ». Counted as in service, read as the sign that providers
  # are registered, which is this ticket's reading and not the chapter's
  # (OOTS-294, RG3); `DSD:ERR:0001` and `0002` are not.
  REGISTERED_REFUSAL = ProviderClassificationRequired::CODE

  # One evidence type, and what the Data Service Directory answered for it.
  Offer = Data.define(:evidence_type, :data_services, :refusal) do
    def publishers = data_services.flat_map(&:providers).filter_map(&:label).uniq

    def formats = data_services.flat_map(&:distribution_formats).uniq

    def registered? = data_services.any? || refusal == REGISTERED_REFUSAL
  end

  # One `sdg:EvidenceTypeList`: its offers are required together.
  Combination = Data.define(:list, :offers)

  # A country, its combinations — alternatives to one another, two lists of
  # the same types shown once, the jurisdiction that tells them apart not
  # being shown — and the `NoMatch` lists by which it declares it issues
  # nothing for the requirement.
  Jurisdiction = Data.define(:code, :name, :combinations, :declarations) do
    def offers = combinations.flat_map(&:offers)

    def publishes? = combinations.any?

    def registered? = offers.any?(&:registered?)
  end

  attr_reader :requirement

  def initialize(snapshot:, requirement:, country_names:)
    query = Directories::RecordedQuery.new(snapshot)
    @evidence_broker = EvidenceBrokerClient.new(query:)
    @data_service_directory = DataServiceDirectoryClient.new(query:)
    @requirement = requirement
    @country_names = country_names
  end

  # `EB:ERR:0001`: the Evidence Broker holds nothing on the requirement.
  def nothing_published? = lists.nil?

  def empty_result_code = Directories::Catalogue::EMPTY_RESULT_SET

  # In the alphabetical order of the country's name in the page's language.
  def jurisdictions
    @jurisdictions ||= Array(lists).select { |list| list.country.present? }.group_by(&:country)
      .map { |code, found| jurisdiction(code, found) }
      .sort_by { |found| ActiveSupport::Inflector.transliterate(found.name).downcase }
  end

  def evidence_type_count = distinct_evidence_types(offers)

  def country_count = jurisdictions.count(&:publishes?)

  def registered = jurisdictions.select(&:registered?)

  def registered_evidence_type_count = distinct_evidence_types(offers.select(&:registered?))

  private

  def offers = jurisdictions.flat_map(&:offers)

  def distinct_evidence_types(found) = found.uniq { |offer| offer.evidence_type.id }.size

  def lists
    return @lists if defined?(@lists)

    @lists = @evidence_broker.evidence_type_lists(requirement_id: requirement.id)
  rescue CommonServicesError => e
    raise unless e.code == Directories::Catalogue::EMPTY_RESULT_SET

    @lists = nil
  end

  def jurisdiction(code, found)
    Jurisdiction.new(
      code:,
      name: @country_names[code].presence || code,
      combinations: EvidenceTypeList.combinations(found).map { |list| combination(list, code) },
      declarations: found.select(&:no_match?),
    )
  end

  def combination(list, country)
    Combination.new(list:, offers: list.evidence_types.map { |type| offer(type, country) })
  end

  def offer(type, country)
    services = @data_service_directory.data_services(evidence_type_classification: type.id, country_code: country)
    Offer.new(evidence_type: type, data_services: services, refusal: nil)
  rescue CommonServicesError => e
    Offer.new(evidence_type: type, data_services: [], refusal: e.code)
  end
end
