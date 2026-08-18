require 'rails_helper'

RSpec.describe Directories::CommonServices do
  subject(:directory) { described_class.new(evidence_broker: broker, data_service_directory: dsd) }

  let(:requirement) { 'https://sr/requirements/1' }
  let(:broker) do
    instance_double(EvidenceBrokerClient, requirement_identifiers: [requirement], evidence_types: [type])
  end
  let(:dsd) { instance_double(DataServiceDirectoryClient, providers: [provider]) }
  let(:type) { build(:evidence_type) }
  let(:provider) { build(:evidence_provider) }

  describe '#evidence_types_for_procedure' do
    it 'chains the two broker queries, the requirement leading to the types' do
      expect(directory.evidence_types_for_procedure('00', 'FI')).to eq([type])

      expect(broker).to have_received(:evidence_types).with(requirement_id: requirement, country_code: 'FI')
    end

    # The procedure is ours, so its requirements are read in our jurisdiction;
    # only the types that satisfy them are read in the country being asked.
    it 'reads the requirements in our own jurisdiction, not in the one asked' do
      directory.evidence_types_for_procedure('00', 'FI')

      expect(broker).to have_received(:requirement_identifiers).with(procedure_code: '00', country_code: 'FR')
    end

    it 'raises on a procedure the broker holds no requirement for' do
      allow(broker).to receive(:requirement_identifiers).and_return([])

      expect { directory.evidence_types_for_procedure('T9', 'FI') }
        .to raise_error(ProcedureCodeNotFound, /T9/)
    end

    it 'turns the broker refusal on an unknown procedure into the same error' do
      allow(broker).to receive(:requirement_identifiers).and_raise(CommonServicesError.new('vide', code: 'EB:ERR:0001'))

      expect { directory.evidence_types_for_procedure('T9', 'FI') }
        .to raise_error(ProcedureCodeNotFound, /T9/)
    end

    it 'turns a refusal on the second query into an unknown evidence type' do
      allow(broker).to receive(:evidence_types).and_raise(CommonServicesError.new('vide', code: 'EB:ERR:0002'))

      expect { directory.evidence_types_for_procedure('00', 'FI') }
        .to raise_error(EvidenceTypeNotFound, /FI/)
    end

    # An outage is not the caller's fault, and translating it into a 422 would
    # blame them for it.
    it 'lets a failure carrying no code through, rather than blaming the caller' do
      allow(broker).to receive(:requirement_identifiers).and_raise(CommonServicesError, 'annuaire injoignable')

      expect { directory.evidence_types_for_procedure('00', 'FI') }
        .to raise_error(CommonServicesError, /injoignable/)
    end
  end

  describe '#providers' do
    it 'resolves a type and a country to the providers holding it' do
      expect(directory.providers(type.id, 'FI')).to eq([provider])

      expect(dsd).to have_received(:providers)
        .with(evidence_type_classification: type.id, country_code: 'FI')
    end

    it 'raises on a country the directory holds no provider for' do
      allow(dsd).to receive(:providers).and_raise(CommonServicesError.new('vide', code: 'DSD:ERR:0001'))

      expect { directory.providers(type.id, 'DE') }.to raise_error(CountryCodeNotFound, /DE/)
    end

    it 'lets an outage through rather than reporting it as an unknown country' do
      allow(dsd).to receive(:providers).and_raise(CommonServicesError, 'annuaire injoignable')

      expect { directory.providers(type.id, 'DE') }.to raise_error(CommonServicesError, /injoignable/)
    end
  end
end
