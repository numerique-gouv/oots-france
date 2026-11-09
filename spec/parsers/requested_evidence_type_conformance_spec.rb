require 'rails_helper'

RSpec.describe RequestedEvidenceTypeConformance do
  subject(:request) { received(RetrievedMessageParser.new(real_envelope('requete'))) }

  def received(message) = judged(message)

  describe 'a request reduced to what the family judges' do
    def reduced(identifier)
      evidence_type = "<sdg:DataServiceEvidenceType>#{identifier}</sdg:DataServiceEvidenceType>"

      described_class.new(query_request(
        "<query:Query><rim:Slot name=\"EvidenceRequest\"><rim:SlotValue>#{evidence_type}</rim:SlotValue></rim:Slot></query:Query>"
      ), specification: EdmSpecification::V2_0)
    end

    it 'accepts an evidence type naming itself' do
      expect(reduced('<sdg:Identifier>urn:example:type</sdg:Identifier>').validate!).to be_a(described_class)
    end

    it 'refuses one naming nothing, under R-EDM-REQ-C106' do
      expect { reduced('').validate! }.to refusing('R-EDM-REQ-C106')
    end
  end

  # `R-EDM-REQ-C106`, `C031`, `C030` and `C033`, on the evidence type asked for.
  # None of these values reaches the answer — the response announces the format
  # France served and copies no description — so they are applied for the only
  # reason left: they are FATAL on a value the request carries.
  describe 'the evidence type asked for, in what nothing echoes' do
    def described_as(&) = with_body { |body| body.sub(%r{<sdg:DataServiceEvidenceType.*?</sdg:DataServiceEvidenceType>}m, &) }

    # The context is the evidence type and the test is
    # `not(normalize-space(sdg:Identifier)='')`, so an element that is not there
    # breaks it as much as one written blank — which is the case the schema
    # leaves open, giving `sdg:Identifier` `minOccurs="0"`.
    it 'refuses one carrying no sdg:Identifier, under R-EDM-REQ-C106' do
      stripped = described_as { |type| type.sub(%r{<sdg:Identifier>.*?</sdg:Identifier>}m, '') }

      expect { stripped.validate! }.to refusing('R-EDM-REQ-C106')
    end

    it 'refuses one whose sdg:Identifier is written blank, under the same rule' do
      blank = described_as { |type| type.sub(%r{(<sdg:Identifier>).*?(</sdg:Identifier>)}m, '\\1   \\2') }

      expect { blank.validate! }.to refusing('R-EDM-REQ-C106')
    end

    # `C031` and `C030` are the pair `AgentConformance#require_language` already
    # reads for an agent's name and a requirement's wordings — the same two
    # assertions a seventh time, on the description beside the titles.
    def with_description(description)
      described_as { |type| type.sub('</sdg:DataServiceEvidenceType>') { "#{description}</sdg:DataServiceEvidenceType>" } }
    end

    it 'refuses a description naming no language, under R-EDM-REQ-C031' do
      expect { with_description('<sdg:Description>Acte</sdg:Description>').validate! }
        .to refusing('R-EDM-REQ-C031')
    end

    it 'refuses one naming a language the list does not publish, under R-EDM-REQ-C030' do
      expect { with_description('<sdg:Description lang="xx">Acte</sdg:Description>').validate! }
        .to refusing('R-EDM-REQ-C030')
    end

    # Compared exactly, the assertion carrying no `i` flag where the list
    # publishes upper case — the reading `LanguageCode` holds the reason for.
    it 'refuses a published code written in lower case' do
      expect { with_description('<sdg:Description lang="fr">Acte</sdg:Description>').validate! }
        .to refusing('R-EDM-REQ-C030')
    end

    it 'accepts a description naming a published code as the list publishes it' do
      written = with_description('<sdg:Description lang="FR">Acte de naissance</sdg:Description>')

      expect(written.validate!).to be(written)
    end

    # `C033` is the code list the specification publishes; `EDM:ERR:0007` is
    # what France has no document for. The pair is what keeps them apart: a
    # format outside the list never reaches the second refusal.
    it 'refuses a format the code list does not publish, under R-EDM-REQ-C033' do
      exotic = described_as { |type| type.sub('application/pdf', 'application/foo') }

      expect { exotic.validate! }.to refusing('R-EDM-REQ-C033')
    end

    it 'accepts a published format France happens not to serve' do
      served = described_as { |type| type.sub('application/pdf', 'image/png') }

      expect(served.validate!).to be(served)
    end
  end
end
