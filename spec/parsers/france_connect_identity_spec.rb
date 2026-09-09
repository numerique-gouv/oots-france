require 'rails_helper'

RSpec.describe FranceConnectIdentity do
  subject(:identity) { described_class.new(id_token:, userinfo:, signed_id_token: 'le-jeton-signe').identity }

  let(:id_token) { { 'sub' => 'un-pseudonyme', 'acr' => 'eidas2', 'amr' => %w[eidas] } }
  let(:userinfo) do
    { 'sub' => 'un-pseudonyme', 'given_name' => 'Freja Marie', 'family_name' => 'Sørensen',
      'birthdate' => '2001-04-17' }
  end

  # Chapter 2.1 §2.2: the mandatory attributes of the minimum data set, carried
  # word for word and in the format the chapter imposes on `sdg:DateOfBirth`.
  it 'carries the minimum data set as FranceConnect+ published it' do
    expect(identity).to have_attributes(given_name: 'Freja Marie', family_name: 'Sørensen',
      birthdate: '2001-04-17')
  end

  # `R-EDM-REQ-C036` and `C037`, both FATAL: the level reached, in the codes of
  # `LevelsOfAssurance-CodeList` and never in the vocabulary of the portal.
  describe 'the level of assurance' do
    it 'reads eidas2 as substantial' do
      expect(identity.level_of_assurance).to eq('Substantial')
    end

    it 'reads eidas3 as high' do
      id_token['acr'] = 'eidas3'

      expect(identity.level_of_assurance).to eq('High')
    end

    it 'reads nothing at all from an ACR value FranceConnect+ does not publish' do
      id_token['acr'] = 'eidas1'

      expect(identity.level_of_assurance).to be_nil
    end
  end

  describe '.reaches?' do
    it 'admits the level asked for and anything above it' do
      expect(described_class.reaches?('eidas2', 'eidas2')).to be(true)
      expect(described_class.reaches?('eidas3', 'eidas2')).to be(true)
    end

    it 'refuses a level below the one asked for, and one it cannot place' do
      expect(described_class.reaches?('eidas2', 'eidas3')).to be(false)
      expect(described_class.reaches?(nil, 'eidas2')).to be(false)
      expect(described_class.reaches?('eidas1', 'eidas2')).to be(false)
    end
  end

  # RG6: `amr` says the identity came through the eIDAS bridge. The claim is an
  # array, which the portal's own sources return and the page describing the
  # European flow words as a single value.
  describe 'the provenance' do
    it 'reads a European identity out of the array' do
      expect(identity).to be_european
    end

    it 'reads it out of a lone string too' do
      id_token['amr'] = 'eidas'

      expect(identity).to be_european
    end

    it 'names nothing when the claim says nothing of the bridge' do
      id_token['amr'] = %w[fc]

      expect(identity.provenance).to be_nil
      expect(identity).not_to be_european
    end
  end

  # RG5, and chapter 2.1 §2.3.1.2: FranceConnect+ documents no claim carrying it
  # for a European user, so the nominal path is an identity held without one.
  describe 'the eIDAS identifier' do
    it 'holds none when no claim carries it, and never writes the pseudonym there' do
      expect(identity.eidas_identifier).to be_nil
      expect(identity.subject).to eq('un-pseudonyme')
    end

    it 'carries the one the claim would hold, exactly as received' do
      userinfo[described_class::PERSON_IDENTIFIER] = 'DK/FR/61f6a1b0'

      expect(identity.eidas_identifier).to eq('DK/FR/61f6a1b0')
    end

    it 'treats an empty claim as no identifier rather than as an empty one' do
      userinfo[described_class::PERSON_IDENTIFIER] = ''

      expect(identity.eidas_identifier).to be_nil
    end
  end

  # Chapter 2.1 §2.4 lets the requester carry them when it receives them, and
  # RG9 has them travel in the portal's own vocabulary.
  describe 'the optional attributes' do
    it 'carries the sex and the place of birth as they came' do
      userinfo.merge!('gender' => 'female', 'birthplace' => 'Aarhus')

      expect(identity).to have_attributes(gender: 'female', place_of_birth: 'Aarhus')
    end

    it 'invents neither when the answer carries neither' do
      expect(identity).to have_attributes(gender: nil, place_of_birth: nil)
    end
  end
end
