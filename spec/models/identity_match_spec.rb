require 'rails_helper'

RSpec.describe IdentityMatch do
  let(:requested) do
    NaturalPerson.new(level_of_assurance: 'Substantial', family_name: 'Sørensen', given_name: 'Freja Marie',
      date_of_birth: '2001-04-17', eidas_identifier: 'DK/FR/61f6a1b0-3d3c-4f24')
  end

  def established(**overrides)
    Demo::UserIdentity.new(family_name: 'Sørensen', given_name: 'Freja Marie', birthdate: '2001-04-17',
      eidas_identifier: 'DK/FR/61f6a1b0-3d3c-4f24', **overrides)
  end

  def match?(identity) = described_class.new(identity, requested).match?

  it 'matches the same person, whatever the case and the outer blanks' do
    expect(match?(established(family_name: ' SØRENSEN '))).to be(true)
  end

  it 'matches a name written in another Unicode form' do
    requested.given_name = 'Zoé'

    expect(match?(established(given_name: 'Zoé'.unicode_normalize(:nfd)))).to be(true)
  end

  it 'refuses another date of birth' do
    expect(match?(established(birthdate: '2001-04-18'))).to be(false)
  end

  it 'refuses another eIDAS identifier where both carry one' do
    expect(match?(established(eidas_identifier: 'DK/FR/8c0d5ea2-77b1-4f0e'))).to be(false)
  end

  it 'compares no identifier one side lacks' do
    expect(match?(established(eidas_identifier: nil))).to be(true)
  end

  it 'matches nobody against a legal person' do
    company = LegalPerson.new(legal_name: 'Sørensen ApS', eidas_identifier: 'DK/FR/61f6a1b0-3d3c-4f24')

    expect(described_class.new(established, company).match?).to be(false)
  end
end
