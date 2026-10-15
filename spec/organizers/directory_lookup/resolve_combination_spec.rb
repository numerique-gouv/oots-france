require 'rails_helper'

RSpec.describe DirectoryLookup::ResolveCombination do
  subject(:resolved) do
    described_class.call(evidence_broker:, data_service_directory:, requirement:, country_code: 'EL',
      evidence_type_list_id: 'ensemble', provider_classifications:)
  end

  let(:requirement) { build(:requirement, id: 'https://sr/requirements/aaa') }
  let(:evidence_broker) { instance_double(EvidenceBrokerClient, evidence_type_lists: [combination]) }
  let(:combination) do
    build(:evidence_type_list, id: 'ensemble', evidence_types: [
      build(:evidence_type, id: 'https://sr/EL/projectathon'), build(:evidence_type, id: 'https://sr/EL/simple'),
    ])
  end
  let(:question) { build(:evidence_provider_classification) }
  let(:provider_classifications) { {} }
  let(:data_service_directory) do
    instance_double(DataServiceDirectoryClient).tap do |double|
      allow(double).to receive(:data_services).and_return([build(:data_service)])
      allow(double).to receive(:data_services).with(hash_including(evidence_type_classification: 'https://sr/EL/projectathon'))
        .and_raise(CommonServicesError.new('DSD:ERR:0005', code: 'DSD:ERR:0005', classifications: [question]))
      allow(double).to receive(:data_services)
        .with(hash_including(evidence_type_classification: 'https://sr/EL/projectathon',
          classifications: { question.id => 'TC03' }))
        .and_return([build(:data_service)])
    end
  end

  # Chapter 3.2.2 §2.3: « at least one Evidence for each Evidence Type
  # specified in one Evidence Type List MUST be provided ».
  it 'resolves every type of the combination, in the order of the list' do
    expect(resolved.lines.map { |line| line.evidence_type.id }).to eq(%w[https://sr/EL/projectathon https://sr/EL/simple])
  end

  # Chapter 3.1.4 §4.4.3.3: `evidence-type-classification` once per query, so
  # the questions are a type's.
  it 'leaves the questions on the line that asks them, and resolves the other' do
    expect(resolved.lines.map(&:failure?)).to eq([true, false])
    expect(resolved.lines.first.provider_classification_questions).to eq([question])
  end

  describe 'with the answers of a line' do
    let(:provider_classifications) { { 'projectathon' => { question.id => 'TC03' } } }

    it 'asks the Data Service Directory again with them, for that line alone' do
      expect(resolved.lines.map(&:success?)).to eq([true, true])
      expect(data_service_directory).to have_received(:data_services)
        .with(hash_including(evidence_type_classification: 'https://sr/EL/simple', classifications: {}))
    end
  end

  describe 'when no combination is chosen among several' do
    subject(:resolved) do
      described_class.call(evidence_broker:, data_service_directory:, requirement:, country_code: 'EL')
    end

    let(:evidence_broker) do
      instance_double(EvidenceBrokerClient, evidence_type_lists: [combination, build(:evidence_type_list, id: 'seule')])
    end

    it 'resolves no line, and says why' do
      expect(resolved).to be_failure
      expect(resolved.error[:key]).to eq(:evidence_type_unchosen)
      expect(resolved.lines).to be_empty
    end
  end

  # The directory changes: a combination remembered on a card may no longer
  # be published.
  it 'resolves no line on a combination no longer published among several' do
    broker = instance_double(EvidenceBrokerClient, evidence_type_lists: [combination, build(:evidence_type_list, id: 'seule')])
    lookup = described_class.call(evidence_broker: broker, data_service_directory:, requirement:, country_code: 'EL',
      evidence_type_list_id: 'disparue')

    expect([lookup.error[:key], lookup.lines]).to eq([:evidence_type_unchosen, []])
  end

  it 'leaves a line with no provider beside the one that has its own' do
    allow(data_service_directory).to receive(:data_services)
      .with(hash_including(evidence_type_classification: 'https://sr/EL/simple')).and_return([])

    expect(resolved.lines.last.error[:key]).to eq(:no_provider)
  end

  it 'resolves no line where the country publishes nothing' do
    broker = instance_double(EvidenceBrokerClient, evidence_type_lists: [build(:evidence_type_list, :no_match)])
    lookup = described_class.call(evidence_broker: broker, data_service_directory:, requirement:, country_code: 'EL')

    expect([lookup.error[:key], lookup.lines]).to eq([:no_evidence_type, []])
  end

  describe 'without a requirement in hand' do
    subject(:resolved) do
      described_class.call(evidence_broker:, data_service_directory:, procedure_code: '00', country_code: 'EL',
        requirement_id: 'aaa', evidence_type_list_id: 'ensemble')
    end

    let(:evidence_broker) do
      instance_double(EvidenceBrokerClient, requirements: [requirement], evidence_type_lists: [combination])
    end

    it 'reads it under the procedure first' do
      expect(resolved.requirement).to eq(requirement)
      expect(resolved.lines.size).to eq(2)
    end
  end
end
