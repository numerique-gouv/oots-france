require 'rails_helper'

RSpec.describe EvidenceProviderClassification do
  subject(:classification) { described_class.new(**attributes) }

  let(:attributes) do
    {
      id: '1254f10f-406e-4f28-b1ba-d107b93fa264',
      scheme_id: 'https://sr.acc.oots.tech.ec.europa.eu/codelists/EL/ProjectathonTestCases',
      type: 'codelist',
      value_expression: 'https://query.cs.acc.oots.tech.ec.europa.eu/codelists/EL/ProjectathonTestCases/8b3b6a31',
      descriptions: { 'EL' => 'Σενάριο Projectathon', 'EN' => 'Projectathon test case' },
    }
  end

  it 'is valid as the Data Service Directory asks it' do
    expect(classification).to be_valid
  end

  # `R-EDM-REQ-C019`.
  it 'refuses an identifier that is not a UUID' do
    attributes[:id] = 'urn:uuid:1254f10f-406e-4f28-b1ba-d107b93fa264'

    expect(classification).not_to be_valid
  end

  # `R-EDM-REQ-C095`.
  it 'refuses a type outside the three the chapter publishes' do
    attributes[:type] = 'Codelist'

    expect(classification).not_to be_valid
  end

  # `R-EDM-REQ-C096`, `C100` and `C101`.
  it 'asks a code list for its scheme and a value expression in https' do
    attributes[:value_expression] = 'http://query.cs.acc.oots.tech.ec.europa.eu/codelists/EL/x'
    attributes.delete(:scheme_id)

    expect(classification.tap(&:valid?).errors.attribute_names).to contain_exactly(:scheme_id, :value_expression)
  end

  it 'asks neither of a string' do
    attributes.merge!(type: 'string', scheme_id: nil, value_expression: nil)

    expect(classification).to be_valid
  end

  # `R-EDM-REQ-C022`.
  it 'refuses a question that does not name its language' do
    attributes[:descriptions] = { '' => 'Projectathon test case' }

    expect(classification).not_to be_valid
  end

  it 'asks its question in English first' do
    expect([classification.question, classification.question_language]).to eq(['Projectathon test case', 'EN'])
  end

  it 'keeps everything but the value when answered' do
    answered = classification.answered('TC03')

    expect([answered.supported_value, answered.descriptions, answered.id])
      .to eq(['TC03', attributes[:descriptions], attributes[:id]])
  end

  it 'reads back what it writes' do
    answered = classification.answered('TC03')

    expect(described_class.from_h(JSON.parse(answered.to_h.to_json))).to eq(answered)
  end

  describe '.answers_for' do
    let(:questions) { [classification, described_class.new(id: '6e0c0b8a-8c1c-4a8f-9b0e-2f1f6d0f1a01', type: 'string')] }

    it 'keeps the answers to these questions alone, whatever the case of the identifier, blanks left out' do
      given = { attributes[:id].upcase => ' TC03 ', '6e0c0b8a-8c1c-4a8f-9b0e-2f1f6d0f1a01' => ' ',
                'aaaaaaaa-0000-4000-8000-000000000000' => 'X' }

      expect(described_class.answers_for(questions, given)).to eq(attributes[:id] => 'TC03')
    end
  end
end
