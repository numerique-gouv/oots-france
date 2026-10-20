require 'rails_helper'

RSpec.describe GenericodeParser do
  subject(:names) { described_class.new(body).names(code_column: 'code', name_column: 'name-FR') }

  let(:body) do
    <<~XML
      <?xml version="1.0"?>
      <gc:CodeList xmlns:gc="http://docs.oasis-open.org/codelist/ns/genericode/1.0/">
        <Identification><ShortName>Procedures</ShortName></Identification>
        <SimpleCodeList>
          <Row>
            <Value ColumnRef="code"><SimpleValue>R1</SimpleValue></Value>
            <Value ColumnRef="name-Value"><SimpleValue>Requesting proof of birth</SimpleValue></Value>
            <Value ColumnRef="name-FR"><SimpleValue>Demander une attestation
              d’enregistrement d’une naissance</SimpleValue></Value>
          </Row>
          <Row>
            <Value ColumnRef="code"><SimpleValue>S1</SimpleValue></Value>
            <Value ColumnRef="name-Value"><SimpleValue>Requesting proof of residence</SimpleValue></Value>
          </Row>
        </SimpleCodeList>
      </gc:CodeList>
    XML
  end

  # The column asked for, not the first one that looks like a name: an OOTS
  # code list carries one per language of the Union.
  it 'reads the column asked for' do
    expect(names).to eq('R1' => 'Demander une attestation d’enregistrement d’une naissance')
  end

  # The published file is indented, and a name read from it lands in a table
  # cell.
  it 'squishes what the file wraps across lines' do
    expect(names['R1']).not_to include("\n")
  end

  # Not every code is translated into every language, and a code with no name
  # in the column asked for is a code the page shows bare.
  it 'leaves out a code the column does not name' do
    expect(names).not_to have_key('S1')
  end

  it 'reads nothing from a document that is not a code list' do
    expect(described_class.new('<html><body>404</body></html>').names(code_column: 'code', name_column: 'x')).to be_empty
  end

  describe '#rows' do
    # Captured at the address the `sdg:ValueExpression` of a `DSD:ERR:0005` named:
    # its values point at their columns by `Id`, a UUID, and not by `ShortName`.
    subject(:rows) { described_class.new(body).rows('code', 'name-Value', 'deprecated', 'name-EN') }

    let(:body) { Rails.root.join('spec/fixtures/common_services/liste_classification_el_projectathon.gc').read }

    it 'finds each column through the identifier the column set gives it' do
      expect(rows.first).to eq('code' => 'TC03', 'name-Value' => 'TC03 - Evidence request error flow due to Basic Registry error',
        'deprecated' => 'false', 'name-EN' => nil)
    end

    it 'reads every row, in the order the list publishes them' do
      expect(rows.pluck('code')).to eq(%w[TC03 TC06 TC09 TC01 TC10 TC02 TC04 TC08])
    end
  end
end
