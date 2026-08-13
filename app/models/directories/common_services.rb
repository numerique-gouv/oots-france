module Directories
  # The central directories the TDD define — the Evidence Broker, which maps a
  # procedure to the evidence types that satisfy it (chapter 3.2.4), and the
  # Data Service Directory, which maps an evidence type and a country to the
  # providers holding it (chapter 3.1.4). The Semantic Repository is consulted
  # when designing, not here.
  #
  # This is where a refusal becomes an exception the interactors already know:
  # both services answer 200 with a named code, and only a handful of those
  # codes mean "the caller asked for something that does not exist" rather than
  # "the directory is unwell".
  class CommonServices
    UNKNOWN_PROCEDURE = %w[EB:ERR:0001 EB:ERR:0005 EB:ERR:0006].freeze
    UNKNOWN_EVIDENCE_TYPE = %w[EB:ERR:0001 EB:ERR:0002].freeze
    NO_PROVIDER = %w[DSD:ERR:0001 DSD:ERR:0002].freeze

    def initialize(evidence_broker: nil, data_service_directory: nil)
      @evidence_broker = evidence_broker || EvidenceBrokerClient.new
      @data_service_directory = data_service_directory || DataServiceDirectoryClient.new
    end

    # Two queries, and they do not take the same country: a procedure is ours,
    # so its requirements are read in our own jurisdiction, where the evidence
    # types that meet them are read in the country being asked.
    def evidence_types_for_procedure(procedure_code, country_code)
      requirement = first_requirement(procedure_code)

      translating(UNKNOWN_EVIDENCE_TYPE, EvidenceTypeNotFound,
        "Aucun type de justificatif pour la démarche « #{procedure_code} » dans le pays « #{country_code} »") do
        @evidence_broker.evidence_types(requirement_id: requirement, country_code:)
      end
    end

    def providers(evidence_type_id, country_code)
      translating(NO_PROVIDER, CountryCodeNotFound,
        "Aucun fournisseur pour le type de justificatif « #{evidence_type_id} » dans le pays « #{country_code} »") do
        @data_service_directory.data_services(
          evidence_type_classification: evidence_type_id,
          country_code:,
        )
      end
    end

    private

    def first_requirement(procedure_code)
      absent = "Code de démarche « #{procedure_code} » introuvable"
      found = translating(UNKNOWN_PROCEDURE, ProcedureCodeNotFound, absent) do
        @evidence_broker.requirement_identifiers(
          procedure_code:, country_code: Settings.common_services_country_code,
        )
      end

      found.first || raise(ProcedureCodeNotFound, "#{absent}.")
    end

    def translating(codes, error, message)
      yield
    rescue CommonServicesError => e
      raise unless codes.include?(e.code)

      raise error, "#{message} : #{e.message}."
    end
  end
end
