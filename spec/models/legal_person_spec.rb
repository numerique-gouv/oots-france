require 'rails_helper'

RSpec.describe LegalPerson do
  it { is_expected.to validate_presence_of(:legal_name) }
  it { is_expected.to validate_presence_of(:eidas_identifier) }

  it 'accepts an identifier of the form the rules impose' do
    expect(build(:legal_person)).to be_valid
  end

  # R-EDM-REQ-C051 makes the identifier `XX/YY/Z…Z`, the two codes being
  # countries. A national identifier written bare travels untouched through the
  # templates and is refused by the correspondent, far from here.
  it 'rejects an identifier that names no country' do
    expect(build(:legal_person, eidas_identifier: 'A2635542Y')).not_to be_valid
  end

  # The case only the rule's `{6,256}` catches: the chapter writes the suffix
  # `ZZZZZZZ` without ever saying it has a minimum length.
  it 'rejects an identifier whose suffix is shorter than six characters' do
    expect(build(:legal_person, eidas_identifier: 'FR/DE/A263')).not_to be_valid
  end

  # `C051` carries the `i` flag, this application deliberately does not: it is
  # the emitter, and ISO 3166-1 alpha-2 codes are written in upper case.
  it 'rejects country codes written in lower case' do
    expect(build(:legal_person, eidas_identifier: 'fr/de/A2635542Y')).not_to be_valid
  end

  # The four optional elements of `sdg:LegalPersonType` have no attribute source
  # in this deployment, and `sdg:Identifier` is `0..n`.
  it 'is valid without any optional identifier' do
    expect(build(:legal_person, identifiers: {})).to be_valid
  end

  it 'accepts the schemes the TDD publish' do
    expect(build(:legal_person, identifiers: { 'VAT' => 'FR12345678901', 'LEI' => '969500HBOM1RJXTLZ57' }))
      .to be_valid
  end

  # The trap the code list guards against: the SIRET identifies an agent of the
  # exchange — the requester, the provider — and R-EDM-REQ-C055 refuses it on the
  # subject of an evidence.
  it 'rejects the scheme French agents are identified by' do
    expect(build(:legal_person, identifiers: { IdentifierScheme::FRENCH => '00000000000002' })).not_to be_valid
  end

  # `Tax` is what the chapter's own example writes, where the code list carries
  # `TAX` and the rule compares to it exactly.
  it 'rejects a published scheme written in another case' do
    expect(build(:legal_person, identifiers: { 'Tax' => 'FR12345678901' })).not_to be_valid
  end

  # One published scheme is not a pass for the table: every key is judged.
  it 'rejects a table where a single scheme is unpublished' do
    person = build(:legal_person, identifiers: { 'VAT' => 'FR12345678901', 'SIRET' => '00000000000002' })

    expect(person).not_to be_valid
    expect(person.errors.full_messages.join).to include('SIRET')
  end

  # A blank value would render as `<sdg:Identifier schemeID="VAT"/>`, asserting
  # an identifier nobody established.
  it 'rejects a published scheme carrying no value' do
    expect(build(:legal_person, identifiers: { 'VAT' => '' })).not_to be_valid
  end

  # A caller with nothing to declare says so with a nil, and must not have to
  # know that an empty table is the only shape the model accepts.
  it 'is valid when the table of identifiers is nil' do
    expect(build(:legal_person, identifiers: nil)).to be_valid
  end
end
