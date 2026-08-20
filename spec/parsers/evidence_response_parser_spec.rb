require 'rails_helper'

RSpec.describe EvidenceResponseParser do
  subject(:response) { RetrievedMessageParser.new(real_envelope('reponseAvecPieceJointe')).body }

  it 'reads the identifier of the request being answered' do
    expect(response.request_id).to start_with('urn:uuid:')
  end

  it 'reads the identifier the response gives itself' do
    expect(response.response_id).to be_present
  end

  # « Evidence Identifier (for evidence response) » of chapter 4.8, taken from
  # the metadata of the object classified `MainEvidence` — never from the
  # package or from a supplementary document, which R-EDM-RESP-S063 shapes
  # differently.
  it 'reads the identifier of the evidence itself' do
    expect(response.evidence_identifier).to eq('f114a58d-3f5e-46f1-b067-d53f88c6619b')
  end

  describe 'the provider that answered' do
    it 'is the agent classified EP' do
      expect(response.provider.ebms_identity.id).to be_present
    end

    it 'carries the scheme its identifier belongs to' do
      expect(response.provider.ebms_identity.type_id).to be_present
    end

    it 'names the country the answer came from' do
      expect(response.provider_country).to eq(response.provider.address.country)
    end
  end

  it 'reads the requester the answer is owed to' do
    expect(response.requester.id).to eq('00000000000002')
  end

  # No error path runs from a portal back to a provider, so a response that is
  # deliverable must not be refused over a field only the journal reads: the
  # exchange would die and nobody would be told.
  describe 'what it tolerates rather than refuses' do
    it 'answers nil when no object is classified MainEvidence' do
      expect(without { |body| body.gsub('MainEvidence', 'Annexe') }.evidence_identifier).to be_nil
    end

    it 'answers nil when the metadata carries no identifier' do
      stripped = without { |body| body.sub(%r{<sdg:Identifier>[^<]*</sdg:Identifier>}, '') }

      expect(stripped.evidence_identifier).to be_nil
    end

    it 'answers nil for the provider when no agent is classified EP' do
      expect(without { |body| body.gsub('>EP<', '>IP<') }.provider).to be_nil
    end
  end

  def without(&) = envelope_with_body('reponseAvecPieceJointe', &).body
end
