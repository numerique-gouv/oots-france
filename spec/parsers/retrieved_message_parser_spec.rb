require 'rails_helper'

# Read against envelopes captured from a real Domibus, not against ones written
# by hand: see `spec/fixtures/README.md` for why that distinction matters here.
RSpec.describe RetrievedMessageParser do
  describe 'an incoming request' do
    subject(:message) { described_class.new(real_envelope('requete')) }

    it 'reads the ebMS action' do
      expect(message.action).to eq(EbmsAction::EXECUTE_QUERY_REQUEST)
    end

    it 'reads the conversation the exchange belongs to' do
      expect(message.conversation_id).to be_present
    end

    it 'reads the sender, which is where the answer goes' do
      expect(message.sender).to be_a(AccessPoint).and(be_valid)
    end

    it 'hands the body to the request parser' do
      expect(message.body).to be_a(EvidenceRequestParser)
    end
  end

  describe 'an incoming response with evidence' do
    subject(:message) { described_class.new(real_envelope('reponseAvecPieceJointe')) }

    it 'hands the body to the response parser' do
      expect(message.body).to be_a(EvidenceResponseParser)
    end

    it 'decodes the evidence, which is a PDF' do
      expect(message.evidence).to start_with('%PDF')
    end
  end

  describe 'an incoming error' do
    subject(:message) { described_class.new(real_envelope('erreurObjetIntrouvable')) }

    it 'hands the body to the error parser' do
      expect(message.body).to be_a(ErrorResponseParser)
    end

    it 'reads the EDM code, the invariant of the exchange' do
      expect(message.body.code).to eq('EDM:ERR:0004')
    end
  end

  describe 'what it refuses' do
    it 'refuses an envelope that is not XML' do
      expect { described_class.new('pas du xml <') }
        .to raise_error(UnreadableMessageError, /Enveloppe SOAP illisible/)
    end

    it 'refuses an envelope with no ebMS header' do
      expect { described_class.new('<soap:Envelope xmlns:soap="http://www.w3.org/2003/05/soap-envelope"/>') }
        .to raise_error(UnreadableMessageError, /Pas d'entête ebMS/)
    end

    it 'refuses an action it does not know, rather than guessing' do
      unknown = real_envelope('requete').sub('ExecuteQueryRequest', 'SomethingElse')

      expect { described_class.new(unknown).body }
        .to raise_error(UnreadableMessageError, /Action ebMS inconnue/)
    end
  end

  # The prefix bound to the ebMS namespace differs from one Domibus response to
  # another — `ns3:` here, `ns5:` there — and one envelope binds `ns5:` to two
  # different namespaces at once. Reading by URI is the only thing that holds.
  it 'reads a header whose namespace prefix differs from the usual one' do
    renamed = real_envelope('requete').gsub('ns5:', 'nsX:').gsub('xmlns:ns5=', 'xmlns:nsX=')

    expect(described_class.new(renamed).action).to eq(EbmsAction::EXECUTE_QUERY_REQUEST)
  end

  # `R-EDM-REQ-C073` et son équivalent pour la réponse imposent une adresse sur
  # l'agent classé `EP`, et n'y imposent que le pays : c'est de là que se lit le
  # pays d'où la réponse est venue.
  it 'reads the country the provider answered from' do
    message = described_class.new(real_envelope('reponseAvecPieceJointe'))

    expect(message.body.provider_country).to eq('FR')
  end
end
