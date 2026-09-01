require 'rails_helper'

RSpec.describe AccessPoint do
  describe '#speaks?' do
    it 'recognises the version among those the access point announces' do
      announcing = build(:access_point, conforms_to: ['oots-edm:v1.2', EdmSpecification::IDENTIFIER])

      expect(announcing).to be_speaks(EdmSpecification::IDENTIFIER)
    end

    it 'refuses an access point that announces only other versions' do
      outdated = build(:access_point, conforms_to: ['oots-edm:v1.0', 'oots-edm:v1.2'])

      expect(outdated).not_to be_speaks(EdmSpecification::IDENTIFIER)
    end

    # Chapter 3.1.4 requires at least one `sdg:ConformsTo`, so silence is a
    # directory saying nothing rather than saying no — and the DSD query already
    # filtered on `specification`. Refusing it would drop a correspondent on the
    # strength of an omission.
    it 'lets through an access point that announces nothing' do
      silent = build(:access_point, conforms_to: [])

      expect(silent).to be_speaks(EdmSpecification::IDENTIFIER)
    end
  end
end
