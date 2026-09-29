require 'rails_helper'

RSpec.describe PreviewConformance do
  def refused_under(rule) = an_instance_of(UnreadableMessageError).and(having_attributes(detail: rule))

  describe 'the flag asking for the preview' do
    it 'reads the four literals of xsd:boolean' do
      expect(%w[true 1 false 0].map { |flag| request_asking_preview(flag).body.possibility_for_preview? })
        .to eq([true, true, false, false])
    end

    it 'reads a literal surrounded by blanks' do
      expect(request_asking_preview(' true ').body.possibility_for_preview?).to be(true)
    end

    # RG4: a flag nobody can read is not a flag set to false.
    it 'refuses anything else, naming the schema' do
      expect { request_asking_preview('peut-être').body.validate! }
        .to raise_error(refused_under(described_class::BOOLEAN_SCHEMA))
    end
  end

  describe 'the addresses of a second request, on the 2.0 line' do
    def carrying(slots) = second_request(location: nil, slots:).body

    it 'accepts both, in https' do
      expect(carrying(preview_slots('https://oots.example/previsualisation/x', 'https://portail.example')).validate!)
        .to be_a(EvidenceRequestParser)
    end

    it 'refuses a PreviewLocation without its ReturnLocation, under R-EDM-REQ-S062' do
      expect { carrying(preview_slots('https://oots.example/p')).validate! }
        .to raise_error(refused_under('R-EDM-REQ-S062'))
    end

    it 'refuses a ReturnLocation without its PreviewLocation, under R-EDM-REQ-S062' do
      expect { carrying(string_slot('ReturnLocation', 'https://portail.example')).validate! }
        .to raise_error(refused_under('R-EDM-REQ-S062'))
    end

    context 'when this deployment runs in https' do
      before { stub_const('ENV', ENV.to_h.merge('URL_OOTS_FRANCE' => 'https://oots.example')) }

      it 'refuses a ReturnLocation in http, under R-EDM-REQ-C120' do
        expect { carrying(preview_slots('https://oots.example/p', 'http://portail.example')).validate! }
          .to raise_error(refused_under('R-EDM-REQ-C120'))
      end

      it 'refuses a PreviewLocation in http, under R-EDM-REQ-C005' do
        expect { carrying(preview_slots('http://oots.example/p', 'https://portail.example')).validate! }
          .to raise_error(refused_under('R-EDM-REQ-C005'))
      end
    end

    # RG25: the local loop and continuous integration run without TLS.
    it 'accepts http where this deployment runs in http' do
      expect(carrying(preview_slots('http://localhost:3000/p', 'http://localhost:3000/r')).validate!)
        .to be_a(EvidenceRequestParser)
    end
  end

  # RG26: `R-EDM-REQ-S019` closes the list of slots on the 1.2 line.
  it 'refuses a ReturnLocation on the 1.2 line, under R-EDM-REQ-S019' do
    request = second_request(location: nil, line: :v1_2,
      slots: preview_slots('https://oots.example/p', 'https://portail.example')).body

    expect { request.validate! }.to raise_error(refused_under('R-EDM-REQ-S019'))
  end

  it 'refuses a PreviewMethod on the 1.2 line, under R-EDM-REQ-S019' do
    request = second_request(location: nil, line: :v1_2,
      slots: preview_slots('https://oots.example/p') + string_slot('PreviewMethod', 'GET')).body

    expect { request.validate! }.to raise_error(refused_under('R-EDM-REQ-S019'))
  end
end
