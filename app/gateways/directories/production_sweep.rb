module Directories
  # Everything the public page of available evidence shows, asked of the
  # production directories: the catalogue, the evidence type lists of each
  # requirement, and the Data Service Directory for each evidence type in the
  # country publishing it — chapter 3.1.4 §4.2.2 makes both parameters
  # mandatory, so one query per pair.
  #
  # Answers the bodies read, by key. Raises on anything the page could not
  # state: an outage, an unreadable or unsigned answer, a refusal other than
  # the three below and the `EB:ERR:0001` `Catalogue` keeps — the copy is then
  # left as it was.
  class ProductionSweep
    TRUST_STORE = Rails.root.join('config/certificats/services_communs_prod.pem').to_s

    # « No data service », « unknown evidence type », « the user must say more »
    # (chapter 3.1.4 §4.4.2): what the page states on the line of a country.
    STATED_REFUSALS = %w[DSD:ERR:0001 DSD:ERR:0002 DSD:ERR:0005].freeze

    def initialize(connection: nil)
      @connection = connection
    end

    def call
      answers = {}
      evidence_broker = EvidenceBrokerClient.new(query: recording(CommonServicesInstance::EVIDENCE_BROKER, answers))
      data_service_directory =
        DataServiceDirectoryClient.new(query: recording(CommonServicesInstance::DATA_SERVICE_DIRECTORY, answers))

      pairs(Catalogue.new(evidence_broker:)).each { |type, country| ask(data_service_directory, type, country) }

      answers
    end

    private

    # Not for the smoke-test requirements, which the page never shows: chapter
    # 3.7 §4, « Clients should limit unnecessary access ».
    def pairs(catalogue)
      requirements = catalogue.requirements.reject(&:smoke_test?)
      lists = requirements.flat_map { |requirement| catalogue.evidence_type_lists(requirement) }

      lists.select { |list| list.country.present? }
        .flat_map { |list| list.evidence_types.map { |type| [type.id, list.country] } }.uniq
    end

    def ask(data_service_directory, type, country)
      data_service_directory.data_services(evidence_type_classification: type, country_code: country)
    rescue CommonServicesError => e
      raise unless e.code.in?(STATED_REFUSALS)
    end

    def recording(service, answers)
      query = CommonServicesQuery.new(service,
        instance: CommonServicesInstance.production(service),
        signature: CommonServicesSignature.new(trust_store_path: TRUST_STORE),
        connection: @connection)

      RecordingQuery.new(query, into: answers)
    end
  end
end
