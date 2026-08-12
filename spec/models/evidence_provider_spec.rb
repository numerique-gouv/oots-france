require 'rails_helper'

RSpec.describe EvidenceProvider do
  describe '.french' do
    subject(:provider) { described_class.french(id: '00000000000001', name: 'Direction interministérielle du numérique') }

    it 'identifies the organisation by its SIRET' do
      expect(provider.ebms_identity)
        .to eq(EbmsIdentity.new(id: '00000000000001', type_id: IdentifierScheme::FRENCH))
    end

    it 'names it in French' do
      expect(provider.descriptions).to eq('FR' => 'Direction interministérielle du numérique')
    end

    it 'carries a French address' do
      expect(provider.address.country).to eq('FR')
    end
  end

  it 'exposes the access point that reaches it, which is how a message is routed' do
    expect(build(:evidence_provider).access_point_id).to eq('blue_gw')
  end

  it 'is invalid without an access point, there being nowhere to send the request' do
    expect(build(:evidence_provider, access_point: nil)).not_to be_valid
  end

  it 'keeps one name per language, as the common services return them' do
    provider = build(:evidence_provider, descriptions: { 'FR' => 'Mairie', 'EN' => 'Town hall' })

    expect(provider.descriptions.keys).to contain_exactly('FR', 'EN')
  end
end
