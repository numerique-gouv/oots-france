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
  # so: `EidasIdentified` holds both subjects to the upper case alone.
  it 'refuses country codes written in lower case' do
    expect(build(:natural_person, eidas_identifier: 'es/at/02635542Y')).not_to be_valid
  end

  it 'refuses an eIDAS identifier carrying no country pair' do
    person = build(:natural_person, eidas_identifier: '02635542Y')

    expect(person).not_to be_valid
    expect(person.errors.full_messages).to include(%r{PAYS/PAYS/IDENTIFIANT})
  end

  # `allow_nil` where the sex and the place of birth take `allow_blank`, and the
  # difference decides a real message: `EvidenceRequestParser` reads `''`, never
  # `nil`, from a `sdg:Identifier` a correspondent sent present and empty, which
  # breaks `R-EDM-REQ-C040` (FATAL). Refusing it here is the whole of what keeps
  # such a request from being answered as though it named someone.
  it 'refuses an eIDAS identifier that arrived present and empty' do
    expect(build(:natural_person, eidas_identifier: '')).not_to be_valid
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

  # Chapter 2.1 §2.4 makes both optional. Nothing in the Schematron judges the
  # sex under a `NaturalPerson` slot, so what is admitted there is the whole of
  # `Gender-CodeList` and not the eIDAS profile alone; the place of birth, which
  # `R-EDM-REQ-C092` reaches wherever it appears, is held to two characters.
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

    # The eIDAS2 profile of the same list. `R-EDM-REQ-C125` and `C126` pair a
    # profile with a `schemeID`, but only under `AuthorizedRepresentative`:
    # under this slot no rule pairs anything, so refusing these codes would turn
    # a request the specification allows into `EDM:ERR:0003`.
    it 'accepts the numeric codes of the eIDAS2 profile' do
      expect(%w[0 1 2 3 4 5 6 9].map { |gender| build(:natural_person, gender:) }).to all(be_valid)
    end

    # Tolerated where `Other` is refused, and the difference is the rules': no
    # rule holds `sdg:Gender` to anything under a `NaturalPerson` slot, so an
    # element a correspondent sent empty is not something France may turn a
    # conformant request away over.
    it 'accepts a sex that arrived present and empty' do
      expect(build(:natural_person, gender: '')).to be_valid
    end

    it 'refuses a sex the code list does not publish at all' do
      person = build(:natural_person, gender: 'other')

      expect(person).not_to be_valid
      expect(person.errors.full_messages.join)
        .to include('other', 'Male, Female, Unspecified, 0, 1, 2, 3, 4, 5, 6, 9')
    end

    # The two the numeric profile skips, and the only thing that keeps the
    # constant from being read as « 0 to 9 ».
    it 'refuses the two numbers the list leaves out' do
      expect(%w[7 8].map { |gender| build(:natural_person, gender:) }).to all(be_invalid)
    end

    # `R-EDM-REQ-C092` (FATAL) holds every free-text element it names to two
    # characters, and names `sdg:PlaceOfBirth` with no ancestor path — so it
    # reaches this slot, where the rules naming the sex stop at
    # `AuthorizedRepresentative`.
    it 'refuses a place of birth of a single character' do
      person = build(:natural_person, place_of_birth: 'A')

      expect(person).not_to be_valid
      expect(person.errors.full_messages.join).to include('Le lieu de naissance', 'au moins deux caractères')
    end

    # Where an empty sex is tolerated, an empty place of birth is not, and the
    # difference is the rules': `R-EDM-REQ-C092` has the element itself for
    # context, so it fires on one sent present and empty just as on one carrying
    # a single character. Only an absent element escapes it, which is what
    # `allow_nil` says and what `text_at` renders as `nil` rather than `''`.
    it 'refuses a place of birth that arrived present and empty' do
      expect(build(:natural_person, place_of_birth: '')).not_to be_valid
    end

    it 'refuses a place of birth made of blanks alone' do
      expect(build(:natural_person, place_of_birth: '   ')).not_to be_valid
    end

    # The rule measures `normalize-space(.)`, so this is one character to it
    # though it is two to `String#length` — the reason the validation is not a
    # length.
    it 'refuses a place of birth padded to two characters by a blank' do
      expect(build(:natural_person, place_of_birth: ' A')).not_to be_valid
    end

    # The border itself, which nothing else in the suite stands on: every other
    # example in the repository carries `Aarhus`, so a rule tightened to three
    # non-blank characters would pass unnoticed without this one.
    it 'accepts a place of birth of exactly two characters' do
      expect(build(:natural_person, place_of_birth: 'Ry')).to be_valid
    end
  end
end
