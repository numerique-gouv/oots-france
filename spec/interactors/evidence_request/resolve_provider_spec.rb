require 'rails_helper'

RSpec.describe EvidenceRequest::ResolveProvider do
  subject(:resolve) { described_class.call(evidence_type:, country_code: 'DE', common_services:) }

  let(:evidence_type) { build(:evidence_type) }
  let(:common_services) { instance_double(Directories::CommonServices, providers:) }

  let(:providers) do
    [
      build(:evidence_provider, access_point: build(:access_point, id: 'AP_DE_01')),
      build(:evidence_provider, access_point: build(:access_point, id: 'AP_DE_02')),
    ]
  end

  # Only the first, for the same reason as the evidence type: choosing among
  # several is chapter 4.10.
  it 'keeps the first provider the country declares' do
    expect(resolve.provider.access_point.id).to eq('AP_DE_01')
  end

  # The access point comes from the DSD with the provider, so the message has
  # its recipient without a second lookup.
  it 'addresses the exchange to the access point the directory named' do
    expect(resolve.recipient.id).to eq('AP_DE_01')
  end

  describe 'a country the directory holds no provider for' do
    it 'fails, naming what was not found' do
      allow(common_services).to receive(:providers).and_raise(CountryCodeNotFound, 'Aucun fournisseur … « IT ».')

      expect(resolve).to be_failure
      expect(resolve.error).to include(key: :unknown_country)
      expect(resolve.error[:errors].first).to include('IT')
    end
  end

  # The directory answers a refusal rather than an empty list, but nothing
  # obliges it to. Without the guard, a nil provider surfaces two steps later
  # as an opaque NoMethodError inside the message builder.
  describe 'a directory that answers with no provider at all' do
    let(:providers) { [] }

    it 'fails, naming the country' do
      expect(resolve).to be_failure
      expect(resolve.error).to include(key: :no_provider, errors: ['DE'])
    end
  end

  describe 'a directory that cannot be reached' do
    it 'fails as an upstream refusal, not as the caller fault' do
      allow(common_services).to receive(:providers).and_raise(CommonServicesError, 'Annuaire injoignable.')

      expect(resolve).to be_failure
      expect(resolve.error).to include(key: :common_services_refused)
    end
  end
end
