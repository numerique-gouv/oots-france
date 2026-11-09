require 'rails_helper'

RSpec.describe RequestEnvelopeConformance do
  def received(message) = judged(message)

  describe 'a request reduced to the envelope the family judges' do
    def reduced(specification_identifier)
      content = string_slot('SpecificationIdentifier', specification_identifier) +
                string_slot('IssueDateTime', '2026-09-14T10:00:00Z')
      fixed = '<query:ResponseOption returnType="LeafClassWithRepositoryItem"/><query:Query queryDefinition="DocumentQuery"/>'

      described_class.new(query_request("#{content}#{fixed}"), specification: EdmSpecification::V2_0)
    end

    it 'accepts the literals the chapter fixes' do
      expect(reduced(EdmSpecification::V2_0.identifier).validate!).to be_a(described_class)
    end

    it 'refuses another version, under R-EDM-REQ-C001' do
      expect { reduced('oots-edm:v1.0').validate! }.to refusing('R-EDM-REQ-C001')
    end
  end

  # `R-EDM-REQ-S001` and `S002` judge the document element, and are judged on it
  # alone: the parser hands the family that element when it found no request.
  describe 'the root element of the document' do
    def judging_root(xml) = described_class.new(nil, specification: EdmSpecification::V2_0).require_query_request(Nokogiri::XML(xml).root)

    it 'refuses a root that is not a QueryRequest, under R-EDM-REQ-S001' do
      expect { judging_root(%(<query:QueryResponse xmlns:query="#{OotsNamespaces::NAMESPACES.fetch('query')}"/>)) }
        .to refusing('R-EDM-REQ-S001')
    end

    it 'refuses a QueryRequest of another namespace, under R-EDM-REQ-S002' do
      expect { judging_root('<q:QueryRequest xmlns:q="urn:example:query"/>') }.to refusing('R-EDM-REQ-S002')
    end
  end

  # `R-EDM-REQ-C002`, `C024` and `C025`: three literals the chapter fixes in the
  # envelope, read to be judged and for nothing else.
  describe 'the fixed values the envelope of a request carries' do
    def with_issue_date_time(value)
      with_body { |body| body.sub(/(<rim:Slot name="IssueDateTime">.*?<rim:Value>)[^<]*/m, "\\1#{value}") }
    end

    it 'refuses a date that is not a timestamp at all, under R-EDM-REQ-C002' do
      expect { with_issue_date_time('hier').validate! }.to refusing('R-EDM-REQ-C002')
    end

    it 'accepts a timestamp carrying a zone and no fraction of a second' do
      expect(with_issue_date_time('2026-09-14T10:00:00Z').validate!).to be_a(described_class)
    end

    # The assertion is anchored at neither end and stops at the seconds, so it
    # measures the shape of a timestamp and not the whole of `xsd:dateTime`:
    # a reader asking for that in full would refuse what the rule admits.
    it 'accepts one carrying neither fraction nor zone' do
      expect(with_issue_date_time('2026-09-14T10:00:00').validate!).to be_a(described_class)
    end

    it 'refuses a return type other than the fixed one, under R-EDM-REQ-C024' do
      expect { with_body { |body| body.sub('LeafClassWithRepositoryItem', 'LeafClass') }.validate! }
        .to refusing('R-EDM-REQ-C024')
    end

    it 'refuses a query definition other than the fixed one, under R-EDM-REQ-C025' do
      expect { with_body { |body| body.sub('queryDefinition="DocumentQuery"', 'queryDefinition="Foo"') }.validate! }
        .to refusing('R-EDM-REQ-C025')
    end
  end

  it 'refuses a request announcing another version of the data model' do
    dated = with_body { |body| body.sub(EdmSpecification.preferred.identifier, 'oots-edm:v1.0') }

    expect { dated.validate! }
      .to raise_error(an_instance_of(UnreadableMessageError).and(having_attributes(detail: 'R-EDM-REQ-C001')))
  end

  # The slot is there, so R-EDM-REQ-S005 is satisfied and it is the value that
  # fails. What the message says of it has to hold without one to name.
  it 'refuses a request whose version slot is present but empty' do
    emptied = with_body do |body|
      body.sub(/(<rim:Slot name="SpecificationIdentifier">.*?<rim:Value>)[^<]*/m, '\\1')
    end

    expect { emptied.validate! }
      .to raise_error(an_instance_of(UnreadableMessageError).and(having_attributes(detail: 'R-EDM-REQ-C001')))
  end

  # CA11: the header announced 2.0 and the body says 1.2. Refused under the
  # rule of the line the header named, which is also the line the exception
  # response goes back in.
  it 'refuses a request whose header announces 2.0 and whose slot says 1.2' do
    contradicting = envelope_with_body('requete') do |body|
      body.sub(EdmSpecification::V2_0.identifier, EdmSpecification::V1_2.identifier)
    end

    expect { received(contradicting).validate! }
      .to raise_error(an_instance_of(UnreadableMessageError).and(having_attributes(detail: 'R-EDM-REQ-C001')))
  end

  # A message with no property announces itself in its slot alone, so a slot
  # France cannot read is what makes the two disagree there: the version falls
  # back on the preferred one, and the refusal is worded in it.
  it 'refuses a request announcing, in its slot alone, a version France does not speak' do
    dated = earlier_line_envelope do |body|
      body.sub(EdmSpecification::V1_2.identifier, 'oots-edm:v1.0')
    end

    expect { received(dated).validate! }
      .to raise_error(an_instance_of(UnreadableMessageError).and(having_attributes(detail: 'R-EDM-REQ-C001')))
    expect(dated.specification).to eq(EdmSpecification.preferred)
  end
end
