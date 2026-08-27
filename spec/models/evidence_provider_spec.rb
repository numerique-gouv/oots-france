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

  # The DSD returns the two separately, and they differ: a Finnish provider
  # answers as `FIKEHA02` behind the access point `AP_FI_03`.
  it 'keeps its own identity apart from the access point carrying messages to it' do
    provider = build(:evidence_provider, identifier: build(:ebms_identity, id: 'FIKEHA02'),
      access_point: build(:access_point, :foreign, id: 'AP_FI_03'))

    expect(provider.ebms_identity.id).to eq('FIKEHA02')
    expect(provider.access_point.id).to eq('AP_FI_03')
  end

  it 'is invalid without an identity, there being no C4 to name in the message' do
    expect(build(:evidence_provider, identifier: nil)).not_to be_valid
  end

  # Answering, France is its own C4 and the reply goes back to whoever sent it.
  it 'needs no access point to answer as the French provider' do
    expect(described_class.french(id: '00000000000001', name: 'DINUM')).to be_valid
  end

  it 'keeps one name per language, as the common services return them' do
    provider = build(:evidence_provider, descriptions: { 'FR' => 'Mairie', 'EN' => 'Town hall' })

    expect(provider.descriptions.keys).to contain_exactly('FR', 'EN')
  end
end
