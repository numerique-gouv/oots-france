require 'rails_helper'

RSpec.describe EvidenceSubjectBuilder do
  let(:namespaces) { { 'sdg' => 'http://data.europa.eu/p4s' } }

  # The partial is interpolated into a response that declares the namespaces, so
  # on its own it is a fragment whose prefixes bind to nothing.
  def parse(fragment) = Nokogiri::XML(%(<racine xmlns:sdg="http://data.europa.eu/p4s">#{fragment}</racine>))

  def rendered(beneficiary) = described_class.new(beneficiary:).render

  describe 'a legal person' do
    subject(:element) { parse(rendered(person)).at_xpath('//sdg:LegalPerson', namespaces) }

    # Exactly what the request states about the same organisation: a level of
    # assurance and two sectoral identifiers, none of which the response admits.
    let(:person) do
      build(:legal_person, identifiers: { 'VAT' => 'FR12345678901', 'LEI' => '969500HBOM1RJXTLZ57' })
    end

    # R-EDM-RESP-S042 (FATAL) admits those two children and no others.
    # Asserted on the list of children rather than on the rendered string, so
    # that a change of indentation does not read as a change of order — which
    # the `xs:sequence` of `sdg:LegalPersonType` imposes too.
    it 'writes the two children the rule admits, and nothing else the request stated' do
      expect(element.element_children.map(&:name)).to eq(%w[LegalPersonIdentifier LegalName])
    end

    # R-EDM-RESP-C033 and C037: the value is present, and its scheme fixed.
    it 'declares the eIDAS scheme on the legal person identifier' do
      identifier = element.at_xpath('./sdg:LegalPersonIdentifier', namespaces)

      expect(identifier['schemeID']).to eq('eidas')
      expect(identifier.text).to eq('FR/DE/A2635542Y')
    end

    it 'writes the company name' do
      expect(element.at_xpath('./sdg:LegalName', namespaces).text).to eq('Établissements Dupont & Fils')
    end
  end

  describe 'a natural person' do
    subject(:element) { parse(rendered(person)).at_xpath('//sdg:NaturalPerson', namespaces) }

    let(:person) { build(:natural_person, eidas_identifier: 'FR/DE/123123123') }

    # R-EDM-RESP-S041 (FATAL) bounds this branch as tightly: no level of
    # assurance here either, where the request states one.
    it 'writes the children the rule admits, in the order the sequence imposes' do
      expect(element.element_children.map(&:name)).to eq(%w[Identifier FamilyName GivenName DateOfBirth])
    end

    it 'declares the eIDAS scheme on the identifier' do
      expect(element.at_xpath('./sdg:Identifier', namespaces)['schemeID']).to eq('eidas')
    end

    context 'when the request carried no eIDAS identifier' do
      let(:person) { build(:natural_person) }

      it 'writes none' do
        expect(element.element_children.map(&:name)).to eq(%w[FamilyName GivenName DateOfBirth])
      end
    end
  end

  # Whoever asked named the subject, and ERB renders outside ActionView:
  # nothing is escaped for us. The identifier is as much a vector as the name —
  # `EIDAS_IDENTIFIER` ends in `\S`, which admits `<` and `&`.
  describe 'escaping' do
    let(:injection) { '</sdg:LegalName><sdg:Injecté/>' }

    it 'escapes the company name' do
      expect_no_injection(build(:legal_person, legal_name: injection))
    end

    it 'escapes the eIDAS identifier of a legal person' do
      expect_no_injection(build(:legal_person, eidas_identifier: "FR/DE/A263#{injection}"))
    end

    it 'escapes the family name of a natural person' do
      expect_no_injection(build(:natural_person, family_name: injection))
    end

    def expect_no_injection(person)
      document = rendered(person)

      expect(document).not_to include('<sdg:Injecté')
      expect(parse(document).errors).to be_empty
    end
  end

  it 'refuses to write a subject it has no branch for' do
    expect { rendered('Dupont') }.to raise_error(ConfigurationError, /String/)
  end
end
