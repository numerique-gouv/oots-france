module Directories
  # The French service providers allowed to ask this deployment for evidence,
  # indexed by SIRET. Stub 4 of `docs/reste_à_faire.md`: it stands in for the
  # authorisation the beneficiary should give, which an eIDAS identity will
  # eventually carry.
  #
  # The French keys of the JSON are an operations contract, as in
  # Directories::CommonServices.
  class EvidenceRequesters
    def initialize(data = Settings.evidence_requesters_data)
      @data = data
    end

    def find(id)
      entry = data[id]
      raise EvidenceRequesterNotFound, I18n.t('models.directories.evidence_requesters.unknown', id:) if entry.nil?

      EvidenceRequester.french(id:, name: entry['nom'], url: entry['url'])
    end

    private

    attr_reader :data
  end
end
