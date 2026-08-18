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
        'models.directories.common_services.no_evidence_type',
        procedure: procedure_code, country: country_code) do
        @evidence_broker.evidence_types(requirement_id: requirement, country_code:)
      end
    end

    def providers(evidence_type_id, country_code)
      translating(NO_PROVIDER, CountryCodeNotFound,
        'models.directories.common_services.no_provider',
        evidence_type: evidence_type_id, country: country_code) do
        @data_service_directory.providers(
          evidence_type_classification: evidence_type_id,
          country_code:,
        )
      end
    end

    private

    # Seule la première exigence est gardée, là où plusieurs exigences d'une
    # même démarche s'ajoutent — voir le chantier 1 de `docs/reste_à_faire.md`.
    def first_requirement(procedure_code)
      found = translating(UNKNOWN_PROCEDURE, ProcedureCodeNotFound,
        'models.directories.common_services.unknown_procedure', procedure: procedure_code) do
        @evidence_broker.requirement_identifiers(
          procedure_code:, country_code: Settings.common_services_country_code,
        )
      end

      found.first || raise(ProcedureCodeNotFound, "#{unknown_procedure(procedure_code)}.")
    end

    def unknown_procedure(code)
      I18n.t('models.directories.common_services.unknown_procedure', procedure: code)
    end

    # The wording travels as a key, and is built only once a refusal has to be
    # said: a message composed on the way in would be composed on every read
    # that succeeds, which is nearly all of them.
    def translating(codes, error, key, **interpolations)
      yield
    rescue CommonServicesError => e
      raise unless codes.include?(e.code)

      raise error, "#{I18n.t(key, **interpolations)} : #{e.message}."
    end
  end
end
