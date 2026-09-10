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
end
