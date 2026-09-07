require 'rails_helper'

RSpec.describe NaturalPerson do
  it { is_expected.to validate_presence_of(:family_name) }
  it { is_expected.to validate_presence_of(:given_name) }
  it { is_expected.to validate_presence_of(:date_of_birth) }

  # The date travels into `sdg:DateOfBirth`, which the TDD type as a date. A
  # French-formatted one would pass through the templates untouched and be
  # rejected by the correspondent, far from where it was introduced.
  it 'rejects a date that is not ISO 8601' do
    expect(build(:natural_person, date_of_birth: '25/11/1965')).not_to be_valid
  end

  it 'accepts an ISO 8601 date' do
    expect(build(:natural_person)).to be_valid
  end

  # The eIDAS identifier is optional: this deployment receives it from the
  # requester's token, which does not always carry one.
  it 'is valid without an eIDAS identifier' do
    expect(build(:natural_person, eidas_identifier: nil)).to be_valid
  end

  # `R-EDM-REQ-C040`, shared with `LegalPerson` through `EidasIdentified`: the
  # country asserting the identity, the country it is asserted to, then at least
  # six non-blank characters.
  it 'accepts an eIDAS identifier of the shape the rule imposes' do
    expect(build(:natural_person, eidas_identifier: 'ES/AT/02635542Y')).to be_valid
  end

  # Stricter than `R-EDM-REQ-C040`, whose `i` flag admits it, and deliberately
  # so — the choice `LegalPerson` already carried, now shared by the concern.
  it 'refuses country codes written in lower case' do
    expect(build(:natural_person, eidas_identifier: 'es/at/02635542Y')).not_to be_valid
  end

  it 'refuses an eIDAS identifier carrying no country pair' do
    person = build(:natural_person, eidas_identifier: '02635542Y')

    expect(person).not_to be_valid
    expect(person.errors.full_messages).to include(%r{PAYS/PAYS/IDENTIFIANT})
  end

  # `R-EDM-REQ-C036` (FATAL) makes the element mandatory, and chapter 4.5.1 §3.6
  # makes the requester answerable for it matching the authentication that took
  # place: there is no value to fall back on.
  describe 'the level of assurance' do
    it 'refuses a person carrying none' do
      person = build(:natural_person, level_of_assurance: nil)

      expect(person).not_to be_valid
      expect(person.errors.full_messages.join).to include('Le niveau de garantie')
    end

    # `R-EDM-REQ-C037` (FATAL) holds it to `LevelsOfAssurance-CodeList`, whose
    # three values these are. The message names what was received and what is
    # admitted, both being what makes the refusal actionable for the portal.
    it 'refuses a level the code list does not publish' do
      person = build(:natural_person, level_of_assurance: 'Medium')

      expect(person).not_to be_valid
      expect(person.errors.full_messages.join).to include('Medium', 'Low, Substantial, High')
    end

    # Written out rather than mapped over `LEVELS_OF_ASSURANCE`: a test drawing
    # its inputs from the constant it is checking cannot fail, a typo in the
    # list being copied into the expectation along with everything else.
    it 'accepts each of the three the code list publishes' do
      expect(%w[Low Substantial High].map { |level| build(:natural_person, level_of_assurance: level) })
        .to all(be_valid)
    end
  end

  # Chapter 2.1 §2.4 makes both optional, and `Gender-CodeList` closes the
  # second one in its eIDAS profile. Nothing in the Schematron judges it under a
  # `NaturalPerson` slot, so this validation is the only thing that does.
  describe 'the optional attributes' do
    it 'is valid carrying neither a sex nor a place of birth' do
      expect(build(:natural_person, gender: nil, place_of_birth: nil)).to be_valid
    end

    it 'accepts a place of birth as free text' do
      expect(build(:natural_person, place_of_birth: 'Aarhus')).to be_valid
    end

    it 'accepts each of the three sexes the eIDAS profile publishes' do
      expect(%w[Male Female Unspecified].map { |gender| build(:natural_person, gender:) }).to all(be_valid)
    end

    # Tolerated where `Other` is refused, and the difference is the rules': no
    # rule holds `sdg:Gender` to anything under a `NaturalPerson` slot, so an
    # element a correspondent sent empty is not something France may turn a
    # conformant request away over.
    it 'accepts a sex that arrived present and empty' do
      expect(build(:natural_person, gender: '')).to be_valid
    end

    it 'refuses a sex the eIDAS profile does not publish' do
      person = build(:natural_person, gender: 'other')

      expect(person).not_to be_valid
      expect(person.errors.full_messages.join).to include('other', 'Male, Female, Unspecified')
    end
  end
end
