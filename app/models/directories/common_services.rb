module Directories
  # Stands in for the three central services the TDD define — the Evidence
  # Broker, which maps a procedure to the evidence types that satisfy it; the
  # Data Service Directory, which maps an evidence type and a country to the
  # providers holding it; and the Semantic Repository, which describes the type
  # itself. Stub 1 of `docs/reste_à_faire.md`.
  #
  # Its JSON keys are French, against the usual rule: they are an operations
  # contract, written by hand in `.env.oots` and by `scripts/ci/
  # preparEnvironnement.sh`. The French stops at this class.
  class CommonServices
    def initialize(data = Settings.common_services_data)
      @data = data
    end

    def evidence_types_for_procedure(code)
      procedure = procedures.find { |declared| declared['code'] == code }
      raise ProcedureCodeNotFound, "Code de démarche « #{code} » introuvable." if procedure.nil?

      procedure.fetch('idsTypeJustificatif', []).map { |id| evidence_type(id) }
    end

    def evidence_type(id)
      declared = evidence_types.find { |candidate| candidate['id'] == id }
      raise EvidenceTypeNotFound, "Type de justificatif « #{id} » introuvable." if declared.nil?

      EvidenceType.new(
        id: declared['id'],
        descriptions: declared['descriptions'] || {},
        distribution_format: declared['formatDistribution'],
      )
    end

    def providers(evidence_type_id, country_code)
      declared = evidence_types.find { |candidate| candidate['id'] == evidence_type_id }
      for_country = declared&.dig('fournisseurs', country_code)

      if for_country.blank?
        raise CountryCodeNotFound,
          "Aucun fournisseur pour le type de justificatif « #{evidence_type_id} » dans le pays « #{country_code} »."
      end

      for_country.map { |entry| build_provider(entry, evidence_type_id, country_code) }
    end

    private

    attr_reader :data

    def evidence_types = data.fetch('typesJustificatif', [])

    def procedures = data.fetch('demarches', [])

    # Checked here and not when the message is built, so an incomplete
    # directory entry names itself instead of surfacing as an unroutable
    # message later.
    def build_provider(entry, evidence_type_id, country_code)
      access_point = AccessPoint.new(
        id: entry.dig('pointAcces', 'id'),
        type_id: entry.dig('pointAcces', 'typeId'),
      )
      access_point.validate!(
        "Le fournisseur du type de justificatif « #{evidence_type_id} » pour le pays « #{country_code} »"
      )

      EvidenceProvider.new(access_point:, descriptions: entry['descriptions'] || {})
    end
  end
end
