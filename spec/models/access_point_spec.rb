require 'rails_helper'

RSpec.describe AccessPoint do
  describe '#specification' do
    it 'prefers 2.0 over the older line an access point announces beside it' do
      announcing = build(:access_point, conforms_to: ['oots-edm:v1.2', 'oots-edm:v2.0'])

      expect(announcing.specification).to eq(EdmSpecification::V2_0)
    end

    it 'takes 1.2 from an access point announcing it alone' do
      legacy = build(:access_point, :legacy_line)

      expect(legacy.specification).to eq(EdmSpecification::V1_2)
    end

    it 'takes 1.2 from an access point announcing it beside a version France does not speak' do
      mixed = build(:access_point, conforms_to: ['oots-edm:v1.0', 'oots-edm:v1.2'])

      expect(mixed.specification).to eq(EdmSpecification::V1_2)
    end

    it 'names none where the access point announces only versions France does not speak' do
      outdated = build(:access_point, conforms_to: ['oots-edm:v1.0', 'oots-edm:v1.1'])

      expect(outdated.specification).to be_nil
    end

    # Chapter 3.1.4 requires at least one `sdg:ConformsTo`, so silence is a
    # directory saying nothing rather than saying no. Refusing it would drop a
    # correspondent on the strength of an omission.
    it 'takes the preferred version from an access point that announces nothing' do
      silent = build(:access_point, conforms_to: [])

      expect(silent.specification).to eq(EdmSpecification.preferred)
    end
  end

  describe '#specification of a requested line' do
    let(:both) { build(:access_point, conforms_to: ['oots-edm:v1.2', 'oots-edm:v2.0']) }

    it 'takes the requested line from an access point announcing both' do
      expect(both.specification(EdmSpecification::V1_2)).to eq(EdmSpecification::V1_2)
      expect(both.specification(EdmSpecification::V2_0)).to eq(EdmSpecification::V2_0)
    end

    it 'names none where the access point does not announce the requested line' do
      recent = build(:access_point, conforms_to: ['oots-edm:v2.0'])

      expect(recent.specification(EdmSpecification::V1_2)).to be_nil
    end

    # The same silence as above: nothing said, so nothing refused.
    it 'takes the requested line from an access point that announces nothing' do
      silent = build(:access_point, conforms_to: [])

      expect(silent.specification(EdmSpecification::V1_2)).to eq(EdmSpecification::V1_2)
    end
  end

  describe '#speaks?' do
    it 'answers from what the access point announces' do
      legacy = build(:access_point, :legacy_line)

      expect(legacy.speaks?(EdmSpecification::V1_2)).to be(true)
      expect(legacy.speaks?(EdmSpecification::V2_0)).to be(false)
    end
  end
end
