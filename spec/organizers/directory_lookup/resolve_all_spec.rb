require 'rails_helper'

RSpec.describe DirectoryLookup::ResolveAll do
  subject(:resolved) do
    described_class.call(evidence_broker:, data_service_directory:, procedure_code: '00', country_code: 'FI')
  end

  let(:evidence_broker) do
    instance_double(EvidenceBrokerClient, requirements:, evidence_type_lists: [build(:evidence_type_list)])
  end
  let(:data_service_directory) { instance_double(DataServiceDirectoryClient, data_services: [build(:data_service)]) }

  let(:requirements) do
    [build(:requirement, id: 'https://sr/requirements/aaa'), build(:requirement, id: 'https://sr/requirements/bbb')]
  end

  it 'resolves every requirement the procedure rests on' do
    expect(resolved.resolutions.map { |lookup| lookup.requirement.id })
      .to eq(['https://sr/requirements/aaa', 'https://sr/requirements/bbb'])
  end

  it 'hands on the requirements themselves, which the page heads its cards with' do
    expect(resolved.requirements).to eq(requirements)
  end

  # The opening run read the whole list, so asking the Evidence Broker for the
  # first requirement again would be a query for an answer already in hand.
  it 'reuses the first run instead of walking it a second time' do
    expect(resolved.resolutions.first.requirement.id).to eq('https://sr/requirements/aaa')

    expect(evidence_broker).to have_received(:evidence_type_lists)
      .with(requirement_id: 'https://sr/requirements/aaa', country_code: 'FI').once
  end

  it 'asks for the others by identifier' do
    resolved

    expect(evidence_broker).to have_received(:evidence_type_lists)
      .with(requirement_id: 'https://sr/requirements/bbb', country_code: 'FI')
  end

  # Step 16 of chapter 1 §10.1 has the user say, evidence by evidence, which
  # member state it is to come from, and chapter 3.2.4 §4.3 has the second query
  # « reflect the country and jurisdiction of the Evidence Provider ».
  describe 'with a country named per requirement' do
    subject(:resolved) do
      described_class.call(evidence_broker:, data_service_directory:, procedure_code: '00', country_code: 'FR',
        countries: { 'bbb' => 'FI' })
    end

    it 'resolves each requirement in its own country, and the others in the default one' do
      expect(resolved.resolutions.map(&:country_code)).to eq(%w[FR FI])
      expect(data_service_directory).to have_received(:data_services).with(hash_including(country_code: 'FI')).once
    end

    # Chapter 3.2.4 §4.2: the first query « should relate to the country of
    # the Evidence Requester », whichever country a card is resolved in.
    it 'never asks for the requirements themselves in the country of a card' do
      resolved

      expect(evidence_broker).not_to have_received(:requirements).with(hash_including(country_code: 'FI'))
    end

    # The opening run answered for its requirement in the default country, and
    # says nothing of what another publishes.
    it 'walks the first requirement again when it is named another country' do
      described_class.call(evidence_broker:, data_service_directory:, procedure_code: '00', country_code: 'FR',
        countries: { 'aaa' => 'DE' })

      expect(evidence_broker).to have_received(:evidence_type_lists)
        .with(requirement_id: 'https://sr/requirements/aaa', country_code: 'DE').once
    end
  end

  # Chapter 4.4 §4.2.2 has the basic flows run « sequentially and/or in
  # parallel », so a refusal belongs to the card it fell on. The page shows it
  # there, beside the neighbours that answered.
  describe 'when a directory refuses one requirement' do
    let(:data_service_directory) do
      instance_double(DataServiceDirectoryClient).tap do |double|
        allow(double).to receive(:data_services).and_invoke(
          ->(**) { [build(:data_service)] },
          ->(**) { raise CommonServicesError.new('DSD:ERR:0001 : rien à donner', code: 'DSD:ERR:0001') },
        )
      end
    end

    it 'leaves the refusal on its own resolution and keeps the others' do
      expect(resolved.resolutions.map(&:failure?)).to eq([false, true])
    end

    it 'still resolves every requirement' do
      expect(resolved.resolutions.size).to eq(2)
    end
  end

  # An outage carries no code: nothing was answered, and there is nothing to
  # show beside it. `Refusing` raises it, and it goes past this object whole.
  describe 'when a directory cannot be reached' do
    let(:data_service_directory) do
      instance_double(DataServiceDirectoryClient).tap do |double|
        allow(double).to receive(:data_services).and_raise(CommonServicesError.new('injoignable'))
      end
    end

    it 'lets the outage through' do
      expect { resolved }.to raise_error(CommonServicesError, 'injoignable')
    end
  end

  # The form `ApplicationInteractor` already uses for the gateway: a caller
  # passes only what varies.
  it 'gives itself the two directories when the caller names none' do
    allow(EvidenceBrokerClient).to receive(:new).and_return(evidence_broker)
    allow(DataServiceDirectoryClient).to receive(:new).and_return(data_service_directory)

    expect(described_class.call(procedure_code: '00', country_code: 'FI').resolutions.size).to eq(2)
  end
end
