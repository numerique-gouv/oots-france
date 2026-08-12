require 'rails_helper'

RSpec.describe EvidenceRequest::ResolveProvider do
  subject(:resolve) { described_class.call(evidence_type:, country_code: 'DE', common_services:) }

  let(:evidence_type) { build(:evidence_type) }
  let(:common_services) { Directories::CommonServices.new(directory) }

  let(:directory) do
    {
      'typesJustificatif' => [
        {
          'id' => evidence_type.id,
          'fournisseurs' => {
            'DE' => [
              { 'pointAcces' => { 'id' => 'AP_DE_01', 'typeId' => scheme }, 'descriptions' => { 'EN' => 'Berlin I' } },
              { 'pointAcces' => { 'id' => 'AP_DE_02', 'typeId' => scheme }, 'descriptions' => { 'EN' => 'Berlin II' } },
            ],
          },
        },
      ],
    }
  end

  let(:scheme) { 'urn:oasis:names:tc:ebcore:partyid-type:unregistered:oots' }

  # Only the first, for the same reason as the evidence type: choosing among
  # several is chapter 4.10.
  it 'keeps the first provider the country declares' do
    expect(resolve.provider.access_point_id).to eq('AP_DE_01')
  end

  describe 'a country the directory holds no provider for' do
    it 'fails, naming what was not found' do
      failed = described_class.call(evidence_type:, country_code: 'IT', common_services:)

      expect(failed).to be_failure
      expect(failed.error).to include(key: :unknown_country)
      expect(failed.error[:errors].first).to include('IT')
    end
  end

  # The stubbed directory raises rather than returning an empty list, but a real
  # Evidence Broker need not. Without the guard, a nil provider surfaces two
  # steps later as an opaque NoMethodError inside the message builder.
  describe 'a directory that answers with no provider at all' do
    let(:common_services) { instance_double(Directories::CommonServices, providers: []) }

    it 'fails, naming the country' do
      expect(resolve).to be_failure
      expect(resolve.error).to include(key: :no_provider, errors: ['DE'])
    end
  end
end
