require 'rails_helper'

RSpec.describe RequestBasis do
  subject(:basis) do
    described_class.new(
      requirement: build(:requirement), provider:, recipient: provider.access_point,
      data_service: build(:data_service), evidence_type: build(:evidence_type), preview_possible: true,
    )
  end

  let(:provider) { build(:evidence_provider, address: build(:address, country: 'FI')) }

  # Chapter 4.9 §2 step 12 wants the second request to repeat the first, so
  # nothing the builder writes may be lost between the two.
  it 'comes back from the exchange as it went in' do
    exchange = create(:exchange, request_basis: basis)
    stored = Exchange.find(exchange.id).request_basis

    expect(stored.to_h).to eq(basis.to_h)
  end

  it 'gives the provider back its access point' do
    stored = described_class.from_h(basis.to_h)

    expect(stored.provider.access_point.id).to eq(stored.recipient.id)
    expect(stored.recipient.conforms_to).to eq(provider.access_point.conforms_to)
  end

  it 'keeps nothing of the subject' do
    expect(basis.to_h.keys)
      .to contain_exactly('requirement', 'provider', 'recipient', 'data_service', 'evidence_type_id', 'preview_possible')
  end
end
