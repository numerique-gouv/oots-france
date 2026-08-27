require 'rails_helper'

RSpec.describe LegalPersonBuilder do
  subject(:element) { parse(described_class.new(person:).render).at_xpath('//sdg:LegalPerson', namespaces) }

  let(:person) { build(:legal_person, identifiers: { 'VAT' => 'FR12345678901', 'LEI' => '969500HBOM1RJXTLZ57' }) }
  let(:namespaces) { { 'sdg' => 'http://data.europa.eu/p4s' } }

  # The partial is interpolated into a message that declares the namespaces, so
  # on its own it is a fragment whose prefixes bind to nothing.
  def parse(fragment) = Nokogiri::XML(%(<racine xmlns:sdg="http://data.europa.eu/p4s">#{fragment}</racine>))

  # `sdg:LegalPersonType` is an `xs:sequence`, and its trap is that the optional
  # `Identifier` comes before the mandatory `LegalPersonIdentifier`. Asserted on
  # the list of children rather than on the rendered string, so that a change of
  # indentation does not read as a change of order.
  it 'writes the children in the order the sequence imposes' do
    expect(element.element_children.map(&:name))
      .to eq(%w[LevelOfAssurance Identifier Identifier LegalPersonIdentifier LegalName])
  end

  # R-EDM-REQ-C047 and C048: present, and one of the three published levels.
  it 'states the level of assurance' do
    expect(element.at_xpath('./sdg:LevelOfAssurance', namespaces).text).to eq('High')
  end

  it 'names the scheme of each optional identifier' do
    expect(element.xpath('./sdg:Identifier', namespaces).pluck('schemeID')).to eq(%w[VAT LEI])
  end

  # R-EDM-REQ-C052 and C053: the attribute is mandatory and its value fixed.
  it 'declares the eIDAS scheme on the legal person identifier' do
    identifier = element.at_xpath('./sdg:LegalPersonIdentifier', namespaces)

    expect(identifier['schemeID']).to eq('eidas')
    expect(identifier.text).to eq('FR/DE/A2635542Y')
  end

  context 'when the subject carries no optional identifier' do
    let(:person) { build(:legal_person, identifiers: {}) }

    it 'writes none' do
      expect(element.element_children.map(&:name))
        .to eq(%w[LevelOfAssurance LegalPersonIdentifier LegalName])
    end
  end

  # Everything here comes from whatever named the subject, and ERB renders
  # outside ActionView: nothing is escaped for us. The identifier is as much a
  # vector as the name — `EIDAS_IDENTIFIER` ends in `\S`, which admits `<` and
  # `&` — and the values of `identifiers` carry no format constraint at all.
  describe 'escaping' do
    let(:injection) { '</sdg:LegalName><sdg:Injecté/>' }

    it 'escapes the company name' do
      expect_no_injection(build(:legal_person, legal_name: injection))
    end

    it 'escapes the eIDAS identifier' do
      expect_no_injection(build(:legal_person, eidas_identifier: "FR/DE/A263#{injection}"))
    end

    it 'escapes the value of an optional identifier' do
      expect_no_injection(build(:legal_person, identifiers: { 'VAT' => injection }))
    end

    def expect_no_injection(person)
      rendered = described_class.new(person:).render

      expect(rendered).not_to include('<sdg:Injecté')
      expect(parse(rendered).errors).to be_empty
    end
  end
end
