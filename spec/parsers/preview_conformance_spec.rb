require 'rails_helper'

RSpec.describe PreviewConformance do
  def received(message) = judged(message)

  describe 'a request reduced to the slots the family judges' do
    def reduced(flag, slots = '')
      described_class.new(query_request(string_slot('PossibilityForPreview', flag) + slots),
        specification: EdmSpecification::V2_0)
    end

    it 'accepts a flag and two paired addresses in https' do
      expect(reduced('true', preview_slots('https://oots.example/p', 'https://portail.example')).validate!)
        .to be_a(described_class)
    end

    it 'refuses an address without its pair, under R-EDM-REQ-S062' do
      expect { reduced('true', preview_slots('https://oots.example/p')).validate! }
        .to refusing('R-EDM-REQ-S062')
    end
  end

  describe 'the flag asking for the preview' do
    it 'reads the four literals of xsd:boolean' do
      expect(%w[true 1 false 0].map { |flag| received(request_asking_preview(flag)).possibility_for_preview? })
        .to eq([true, true, false, false])
    end

    it 'reads a literal surrounded by blanks' do
      expect(received(request_asking_preview(' true ')).possibility_for_preview?).to be(true)
    end

    # RG4: a flag nobody can read is not a flag set to false.
    it 'refuses anything else, naming the schema' do
      expect { received(request_asking_preview('peut-être')).validate! }
        .to refusing(described_class::BOOLEAN_SCHEMA)
    end
  end

  describe 'the addresses of a second request, on the 2.0 line' do
    def carrying(slots) = received(second_request(location: nil, slots:))

    it 'accepts both, in https' do
      expect(carrying(preview_slots('https://oots.example/previsualisation/x', 'https://portail.example')).validate!)
        .to be_a(described_class)
    end

    it 'refuses a PreviewLocation without its ReturnLocation, under R-EDM-REQ-S062' do
      expect { carrying(preview_slots('https://oots.example/p')).validate! }
        .to refusing('R-EDM-REQ-S062')
    end

    it 'refuses a ReturnLocation without its PreviewLocation, under R-EDM-REQ-S062' do
      expect { carrying(string_slot('ReturnLocation', 'https://portail.example')).validate! }
        .to refusing('R-EDM-REQ-S062')
    end

    context 'when this deployment runs in https' do
      before { stub_const('ENV', ENV.to_h.merge('URL_OOTS_FRANCE' => 'https://oots.example')) }

      it 'refuses a ReturnLocation in http, under R-EDM-REQ-C120' do
        expect { carrying(preview_slots('https://oots.example/p', 'http://portail.example')).validate! }
          .to refusing('R-EDM-REQ-C120')
      end

      it 'refuses a PreviewLocation in http, under R-EDM-REQ-C005' do
        expect { carrying(preview_slots('http://oots.example/p', 'https://portail.example')).validate! }
          .to refusing('R-EDM-REQ-C005')
      end
    end

    # RG25: the local loop and continuous integration run without TLS.
    it 'accepts http where this deployment runs in http' do
      expect(carrying(preview_slots('http://localhost:3000/p', 'http://localhost:3000/r')).validate!)
        .to be_a(described_class)
    end
  end
end
