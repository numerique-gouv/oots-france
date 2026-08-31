require 'rails_helper'

RSpec.describe Directories::CommonServices do
  subject(:directory) { described_class.new(evidence_broker: broker, data_service_directory: dsd) }

  let(:requirement) { build(:requirement) }
  let(:broker) do
    instance_double(EvidenceBrokerClient, requirements: [requirement], evidence_types: [type])
  end
  let(:dsd) { instance_double(DataServiceDirectoryClient, data_services: [service]) }
  let(:type) { build(:evidence_type) }
  let(:service) { build(:data_service) }

  describe '#evidence_types_for_procedure' do
    it 'chains the two broker queries, the requirement leading to the types' do
      expect(directory.evidence_types_for_procedure('00', 'FI'))
        .to eq(described_class::RequiredEvidence.new(requirement:, evidence_types: [type]))

      expect(broker).to have_received(:evidence_types).with(requirement_id: requirement.id, country_code: 'FI')
    end

    # The procedure is ours, so its requirements are read in our jurisdiction;
    # only the types that satisfy them are read in the country being asked.
    it 'reads the requirements in our own jurisdiction, not in the one asked' do
      directory.evidence_types_for_procedure('00', 'FI')

      expect(broker).to have_received(:requirements).with(procedure_code: '00', country_code: 'FR')
    end

    it 'raises on a procedure the broker holds no requirement for' do
      allow(broker).to receive(:requirements).and_return([])

      expect { directory.evidence_types_for_procedure('T9', 'FI') }
        .to raise_error(ProcedureCodeNotFound, /T9/)
    end

    it 'turns the broker refusal on an unknown procedure into the same error' do
      allow(broker).to receive(:requirements).and_raise(CommonServicesError.new('vide', code: 'EB:ERR:0001'))

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
      allow(broker).to receive(:requirements).and_raise(CommonServicesError, 'annuaire injoignable')

      expect { directory.evidence_types_for_procedure('00', 'FI') }
        .to raise_error(CommonServicesError, /injoignable/)
    end

    # R-EDM-REQ-C008 bounds the shape of that identifier, and a directory is not
    # obliged to honour it — the console lists such an entry, a message cannot
    # carry it.
    it 'refuses a requirement whose identifier no message could carry' do
      allow(broker).to receive(:requirements).and_return([build(:requirement, id: 'https://sr/exigence/1')])

      expect { directory.evidence_types_for_procedure('00', 'FI') }
        .to raise_error(InvalidDirectoryEntry, /L'exigence annoncée/)
    end
  end

  describe '#data_service' do
    # The service and not the provider alone: a request adopts the record, its
    # identifier and its distribution included, and the provider is one of the
    # things that record holds.
    it 'resolves a type and a country to the service delivering it' do
      expect(directory.data_service(type.id, 'FI')).to eq(service)

      expect(dsd).to have_received(:data_services)
        .with(evidence_type_classification: type.id, country_code: 'FI')
    end

    # A record published without `sdg:AccessService` breaks R-DSD-RESP-S014;
    # writing its identifier would pair it with a provider another record
    # announced, and refusing the exchange would ignore a service that works.
    it 'keeps the first service that names a provider, not simply the first' do
      silent = build(:data_service, id: 'a3ff6ed8-1cbf-4a4a-9d20-3fa1c0ef7ac5', providers: [])
      allow(dsd).to receive(:data_services).and_return([silent, service])

      expect(directory.data_service(type.id, 'FI')).to eq(service)
    end

    it 'answers nothing when no service names a provider' do
      allow(dsd).to receive(:data_services).and_return([build(:data_service, providers: [])])

      expect(directory.data_service(type.id, 'FI')).to be_nil
    end

    # R-EDM-REQ-C026 makes that identifier a UUID, and R-EDM-REQ-C027 the
    # classification a Semantic Repository URL.
    it 'refuses a service whose identifier no message could carry' do
      allow(dsd).to receive(:data_services).and_return([build(:data_service, id: 'service-de-test')])

      expect { directory.data_service(type.id, 'FI') }
        .to raise_error(InvalidDirectoryEntry, /Le service de données annoncé/)
    end

    # R-DSD-RESP-C010 bounds the data model the directory may publish, and the
    # request carries that value back word for word: an entry breaking it would
    # reach a correspondent as a URL pointing at nothing.
    it 'refuses a service whose data model no message could carry' do
      published = build(:data_service, distribution_conforms_to: 'https://sr.oots.tech.ec.europa.eu/distributions/1')
      allow(dsd).to receive(:data_services).and_return([published])

      expect { directory.data_service(type.id, 'FI') }
        .to raise_error(InvalidDirectoryEntry, /Le modèle de données/)
    end

    # Refused rather than skipped over: a directory that publishes an entry the
    # rules refuse says something about that directory, where quietly asking the
    # next one would hide it until a correspondent rejected the message.
    it 'refuses on the first service it retained, without falling back on the next' do
      allow(dsd).to receive(:data_services).and_return([build(:data_service, id: 'service-de-test'), service])

      expect { directory.data_service(type.id, 'FI') }.to raise_error(InvalidDirectoryEntry)
    end

    it 'raises on a country the directory holds no provider for' do
      allow(dsd).to receive(:data_services).and_raise(CommonServicesError.new('vide', code: 'DSD:ERR:0001'))

      expect { directory.data_service(type.id, 'DE') }.to raise_error(CountryCodeNotFound, /DE/)
    end

    it 'lets an outage through rather than reporting it as an unknown country' do
      allow(dsd).to receive(:data_services).and_raise(CommonServicesError, 'annuaire injoignable')

      expect { directory.data_service(type.id, 'DE') }.to raise_error(CommonServicesError, /injoignable/)
    end

    # `DSD:ERR:0005` is not a refusal: the country holds several providers and
    # asks the user to narrow it down. Translating it into an unknown country
    # would lose the question, so it travels intact — the lists above name what
    # is refused, and this is not among them.
    it 'passes the request for a user answer through, questions and all' do
      asked = UserAttributesRequired.new('à préciser', classifications: [EvidenceProviderClassification.new])
      allow(dsd).to receive(:data_services).and_raise(asked)

      expect { directory.data_service(type.id, 'FI') }
        .to raise_error(UserAttributesRequired) { |raised| expect(raised.classifications.size).to eq(1) }
    end
  end

  # `translating` names a refusal with a key rather than a sentence, and only
  # composes it once a directory has refused: nothing static ties the two.
  it 'says every refusal it translates' do
    refused = File.read('app/models/directories/common_services.rb')
      .scan(/'(models\.directories(?:\.[a-z_]+)+)'/).flatten.uniq

    expect_said(refused)
  end
end
