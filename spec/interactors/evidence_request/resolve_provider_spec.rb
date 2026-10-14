require 'rails_helper'

RSpec.describe EvidenceRequest::ResolveProvider do
  subject(:resolve) { described_class.call(evidence_type:, country_code: 'DE', common_services:) }

  let(:evidence_type) { build(:evidence_type) }
  let(:common_services) { instance_double(Directories::CommonServices, data_service:) }

  let(:data_service) do
    build(:data_service, providers: [
      build(:evidence_provider, access_point: build(:access_point, :foreign)),
      build(:evidence_provider, access_point: build(:access_point, :foreign, id: 'AP_DE_02')),
    ])
  end

  # Only the first, for the same reason as the evidence type: choosing among
  # several is chapter 4.10.
  it 'keeps the first provider the country declares' do
    expect(resolve.provider.access_point.id).to eq('AP_DE_01')
  end

  # The `DataServiceEvidenceType` of the request is adopted from it (chapter
  # 4.5.1), identifier and distribution included.
  it 'keeps the service the directory named' do
    expect(resolve.data_service).to eq(data_service)
  end

  # Told apart from an outage, which the same `CommonServicesError` family
  # carries: retrying will not make the directory publish something else.
  it 'reports an entry the directory published against the rules under its own key' do
    allow(common_services).to receive(:data_service)
      .and_raise(InvalidDirectoryEntry, "Le service de données annoncé par l'annuaire : …")

    expect(resolve).to be_failure
    expect(resolve.error).to include(key: :invalid_directory_entry)
  end

  # The access point comes from the DSD with the provider, so the message has
  # its recipient without a second lookup.
  it 'addresses the exchange to the access point the directory named' do
    expect(resolve.recipient.id).to eq('AP_DE_01')
  end

  describe 'a country the directory holds no provider for' do
    it 'fails, naming what was not found' do
      allow(common_services).to receive(:data_service).and_raise(CountryCodeNotFound, 'Aucun fournisseur … « IT ».')

      expect(resolve).to be_failure
      expect(resolve.error).to include(key: :unknown_country)
      expect(resolve.error[:errors].first).to include('IT')
    end
  end

  # The directory answers a refusal rather than an empty list, but nothing
  # obliges it to. Without the guard, a nil provider surfaces two steps later
  # as an opaque NoMethodError inside the message builder.
  describe 'a directory that answers with no usable service at all' do
    let(:data_service) { nil }

    it 'fails, naming the country' do
      expect(resolve).to be_failure
      expect(resolve.error).to include(key: :no_provider, errors: ['DE'])
    end
  end

  describe 'a directory that cannot be reached' do
    it 'fails as an upstream refusal, not as the caller fault' do
      allow(common_services).to receive(:data_service).and_raise(CommonServicesError, 'Annuaire injoignable.')

      expect(resolve).to be_failure
      expect(resolve.error).to include(key: :common_services_refused)
    end
  end

  describe 'a question the directory asks about the provider' do
    subject(:resolve) do
      described_class.call(evidence_type:, country_code: 'EL', common_services:, provider_classification_answers:)
    end

    let(:question) { build(:evidence_provider_classification) }
    let(:provider_classification_answers) { { question.id => 'TC03' } }
    let(:data_service) { build(:data_service, classifications: [question.answered('TC03')]) }

    # Chapter 3.1.4 §4.2.2: « The user selected parameter and value MUST be used
    # when responding to a DSD exception DSD:ERR:0005 received ».
    it 'asks the directory with the answers the caller passed' do
      resolve

      expect(common_services).to have_received(:data_service)
        .with(evidence_type.id, 'EL', classifications: provider_classification_answers)
    end

    # Chapter 4.5.1 §3.4: the structure from the directory's answer, the value
    # from the user.
    it 'keeps each classification the user answered, carrying the answer' do
      expect(resolve.provider_classifications).to eq([question.answered('TC03')])
    end

    it 'refuses under its own name a question nobody answered' do
      allow(common_services).to receive(:data_service)
        .and_raise(ProviderClassificationRequired.new('précision', classifications: [question]))

      expect(resolve.error[:key]).to eq(:provider_classification_required)
    end

    it 'keeps no classification when nothing was asked' do
      expect(described_class.call(evidence_type:, country_code: 'EL', common_services:).provider_classifications).to eq([])
    end
  end
end
