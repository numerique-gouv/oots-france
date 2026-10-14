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
      .to contain_exactly('requirement', 'provider', 'recipient', 'data_service', 'evidence_type_id', 'preview_possible',
        'provider_classifications')
  end

  # Chapter 4.9 §2 step 12: « For all rim:Slots except IssueDateTime », the
  # `EvidenceProviderClassification` slot among them — whose values the portal
  # gives again, an answer possibly describing the subject.
  it 'keeps the classifications the user answered, without their values' do
    answered = build(:evidence_provider_classification).answered('TC03')
    exchange = create(:exchange, request_basis: described_class.from_h(basis.to_h.merge(
      'provider_classifications' => [answered.to_h],
    )))

    expect(Exchange.find(exchange.id).request_basis.provider_classifications).to eq([answered.answered(nil)])
  end

  # The slot is `0..n`: a basis written without the key names its provider
  # without having asked anything.
  it 'reads a basis carrying no classification as one that asked nothing' do
    expect(described_class.from_h(basis.to_h.except('provider_classifications')).provider_classifications).to eq([])
  end
end
