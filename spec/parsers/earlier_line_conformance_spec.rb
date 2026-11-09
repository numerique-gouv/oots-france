require 'rails_helper'

RSpec.describe EarlierLineConformance do
  subject(:request) { received(RetrievedMessageParser.new(real_envelope('requete'))) }

  def received(message) = judged(message)

  # The real request downgraded to the 1.2 line, which is what this family judges.
  def earlier(&) = received(earlier_line_envelope(&))

  describe 'a request reduced to what the family judges' do
    def reduced(language)
      described_class.new(query_request(
        '<rim:Slot name="Procedure"><rim:SlotValue xsi:type="rim:InternationalStringValueType"><rim:Value>' \
        "<rim:LocalizedString xml:lang=\"#{language}\" value=\"00\"/></rim:Value></rim:SlotValue></rim:Slot><query:Query/>"
      ), specification: EdmSpecification::V1_2)
    end

    it 'accepts a procedure named in a published language' do
      expect(reduced('EN').validate!).to be_a(described_class)
    end

    it 'refuses one named in no published language, under R-EDM-REQ-C004' do
      expect { reduced('xx').validate! }.to refusing('R-EDM-REQ-C004')
    end
  end

  # Called by the parser where it reads the formats, and not by `validate!`:
  # the count commands that reading.
  describe 'the count of the distributions asked for' do
    def counting(count, specification)
      distributions = query_request('<sdg:DistributedAs/>' * count).xpath('sdg:DistributedAs', OotsNamespaces::NAMESPACES)

      described_class.new(query_request(''), specification:).require_counted_distributions(distributions)
    end

    it 'admits two on the 2.0 line' do
      expect { counting(2, EdmSpecification::V2_0) }.not_to raise_error
    end

    it 'refuses none on the 2.0 line, under R-EDM-REQ-C032' do
      expect { counting(0, EdmSpecification::V2_0) }.to refusing('R-EDM-REQ-C032')
    end

    it 'refuses two on the 1.2 line, under R-EDM-REQ-C032' do
      expect { counting(2, EdmSpecification::V1_2) }.to refusing('R-EDM-REQ-C032')
    end

    it 'refuses none on the 1.2 line, naming the chapter' do
      expect { counting(0, EdmSpecification::V1_2) }.to refusing(described_class::DISTRIBUTION_REQUIRED)
    end
  end

  # `R-EDM-REQ-C004` and `C069`, published at the 1.2.5 tag alone. The context
  # of each is the attribute itself, so neither ever requires it — and one
  # written empty is a context node, which falls on the comparison. Compared
  # exactly, both assertions carrying no `i` flag where the list publishes
  # upper case.
  describe 'the languages the request names' do
    def procedure_in(language) = earlier { |body| body.sub('xml:lang="EN"', %(xml:lang="#{language}")) }

    def requested_in(language, envelope_of)
      envelope_of.call { |body| body.sub('<query:QueryRequest', %(<query:QueryRequest xml:lang="#{language}")) }
    end

    it 'refuses a procedure whose localised string names no published code, under R-EDM-REQ-C004' do
      expect { procedure_in('xx').validate! }.to refusing('R-EDM-REQ-C004')
    end

    it 'accepts a published code written as the list publishes it' do
      expect(procedure_in('FR').validate!).to be_a(described_class)
    end

    it 'refuses that same code in lower case, the assertion carrying no i flag' do
      expect { procedure_in('fr').validate! }.to refusing('R-EDM-REQ-C004')
    end

    # The other half of the pair, which `C069` had and `C004` had not: what
    # confines the rule to its line is a one-line predicate, and a slip in its
    # polarity — or the two predicates swapped — would show up here and
    # nowhere else in this file. The slot keeps the `rim:StringValueType` the
    # 2.0 line types it with, `R-EDM-REQ-S022` being what would otherwise
    # refuse the request first and mask the answer.
    it 'says nothing of the language of a localised string on the 2.0 line' do
      localised = with_body do |body|
        body.sub('<rim:Value>00</rim:Value>', '<rim:Value><rim:LocalizedString xml:lang="xx" value="00"/></rim:Value>')
      end

      expect(localised.validate!).to be_a(described_class)
    end

    it 'refuses a request whose own language names no published code, under R-EDM-REQ-C069' do
      expect { requested_in('xx', method(:earlier)).validate! }.to refusing('R-EDM-REQ-C069')
    end

    it 'accepts a published code on the request itself' do
      expect(requested_in('FR', method(:earlier)).validate!).to be_a(described_class)
    end

    it 'refuses that one in lower case too' do
      expect { requested_in('fr', method(:earlier)).validate! }.to refusing('R-EDM-REQ-C069')
    end

    # The 2.0 line publishes no rule of *that* identifier, the language having
    # moved into each distribution — but it does not fall silent on the
    # attribute: `R-EDM-REQ-S059` forbids it outright, so the two lines say
    # opposite things about one and the same `xml:lang`. A published code is
    # refused there exactly as an unpublished one is, the rule reading the
    # attribute's presence and never its value.
    it 'refuses that attribute outright on the 2.0 line, under R-EDM-REQ-S059' do
      expect { requested_in('xx', method(:with_body)).validate! }.to refusing('R-EDM-REQ-S059')
    end

    it 'refuses it on the 2.0 line even where the code is a published one' do
      expect { requested_in('FR', method(:with_body)).validate! }.to refusing('R-EDM-REQ-S059')
    end

    it 'accepts a 2.0 request naming no language of its own at all' do
      expect(request.validate!).to be_a(described_class)
    end
  end

  # `R-EDM-REQ-C035`, `C072` and `C113`, on the `sdg:Transformation` the 1.2.0
  # profile alone gives `EvidenceTypeDistributionType`. `C113` is `CAUTION` and
  # refuses nothing, as `S014` does not.
  describe 'the transformation a distribution asks for' do
    # The data model the transformation names a subset of, which `C072` counts
    # beside it. A method and not a constant: a constant declared in a block
    # leaks into the whole suite.
    def model = 'https://sr.oots.tech.ec.europa.eu/datamodels/1c9a2e1e-1f1a-4b0e-9c2b-2f5e6a3d7c40'

    def transformed(value, conformance: model, envelope_of: method(:earlier))
      conforms = conformance && "<sdg:ConformsTo>#{conformance}</sdg:ConformsTo>"
      envelope_of.call do |body|
        body.sub('</sdg:DistributedAs>') { "#{conforms}<sdg:Transformation>#{value}</sdg:Transformation></sdg:DistributedAs>" }
      end
    end

    it 'accepts one the semantic repository publishes, beside its data model' do
      expect(transformed("#{model}/subset").validate!).to be_a(described_class)
    end

    # The assertion admits an environment infix — `sr.acc.oots.tech…` — which
    # the prose of chapter 4.5.1 §3.5 does not cite. The expression is copied
    # from the assertion, so what it admits is accepted.
    it 'accepts one carrying an environment infix, as the assertion admits' do
      expect(transformed('https://sr.acc.oots.tech.ec.europa.eu/datamodels/x/y').validate!)
        .to be_a(described_class)
    end

    it 'refuses one naming another host entirely, under R-EDM-REQ-C035' do
      expect { transformed('https://example.org/subset').validate! }.to refusing('R-EDM-REQ-C035')
    end

    it 'refuses one written empty, the element being its own context node' do
      expect { transformed('').validate! }.to refusing('R-EDM-REQ-C035')
    end

    # The alternation sits at the top level of the assertion, so `^` binds the
    # left branch alone: anything at all carrying `distributions/` satisfies
    # the rule. Copied and not tightened, for the reason `C008` is.
    it 'accepts any value carrying distributions/, the alternation being unanchored' do
      expect(transformed('https://example.org/distributions/x').validate!).to be_a(described_class)
    end

    it 'refuses a transformation whose distribution names no data model, under R-EDM-REQ-C072' do
      expect { transformed("#{model}/subset", conformance: nil).validate! }.to refusing('R-EDM-REQ-C072')
    end

    # 2.0.1 publishes no `C035` at all, and keeps `C072` on a context the
    # schema no longer lets a document reach. Neither is applied there.
    it 'says nothing of a transformation on the 2.0 line' do
      described = transformed('https://example.org/subset', conformance: nil, envelope_of: method(:with_body))

      expect(described.validate!).to be_a(described_class)
    end
  end
end
