require 'rails_helper'

RSpec.describe EvidenceRequester do
  it { is_expected.to validate_presence_of(:id) }

  describe 'the identifier scheme' do
    it 'defaults to the French SIRET scheme when none is given' do
      expect(build(:evidence_requester).type_id).to eq(IdentifierScheme::FRENCH)
    end

    # Only *absence* means French. A blank scheme is a directory entry filled in
    # wrong, and substituting a default there would route the message under an
    # identity nobody chose.
    it 'leaves a blank scheme blank, so the identity fails validation' do
      requester = build(:evidence_requester, type_id: '  ')

      expect(requester.ebms_identity).not_to be_valid
    end

    it 'keeps a foreign scheme untouched' do
      requester = build(:evidence_requester, type_id: 'urn:cef.eu:names:identifier:EAS:9930')

      expect(requester.type_id).to eq('urn:cef.eu:names:identifier:EAS:9930')
    end
  end

  it 'defaults the name language to French' do
    expect(build(:evidence_requester).language).to eq('FR')
  end

  it 'carries a French address' do
    expect(build(:evidence_requester).address.country).to eq('FR')
  end

  describe '.intermediary_platform' do
    subject(:platform) { described_class.intermediary_platform }

    # OOTS-France declares itself as a second agent on every request it relays,
    # classified IP. It has no SIRET, hence the fallback scheme — see the
    # "Identifier une organisation" section of docs/oots_context.md.
    it 'identifies itself under the fallback scheme, having no SIRET' do
      expect(platform.type_id).to eq(IdentifierScheme::FRENCH_FALLBACK)
    end

    it 'names itself in English, unlike the requesters it relays' do
      expect(platform.language).to eq('EN')
    end

    it 'yields a valid ebMS identity' do
      expect(platform.ebms_identity).to be_valid
    end
  end

  describe '#jwks_url' do
    # The beneficiary token is signed by the requester: its public keys have to
    # be fetched from the requester itself, at the same path we publish ours.
    it 'points at the requester own key set' do
      expect(build(:evidence_requester).jwks_url).to eq('http://localhost:4000/auth/cles_publiques')
    end
  end
end
