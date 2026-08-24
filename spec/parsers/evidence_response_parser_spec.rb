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

  # Chapter 4.5.2: the status tells a deferral from an answer carrying the
  # document, and `R-EDM-RESP-S045` puts the announced date in a slot that
  # `R-EDM-RESP-S014` forbids to any other status.
  describe 'a response announcing the evidence for later' do
    subject(:deferred) { RetrievedMessageParser.new(built_envelope('reponseDifferee')).body }

    it 'is recognised by its status' do
      expect(deferred).to be_unavailable
    end

    it 'reads the date the evidence is announced for' do
      expect(deferred.response_available_at).to eq(Time.zone.parse('2026-08-07T10:00:00Z'))
    end

    it 'still correlates to the request it answers' do
      expect(deferred.request_id).to eq('urn:uuid:cdd87e02-2bdc-4ce6-bdc9-79e05adae700')
    end

    it 'is not what a response carrying the evidence looks like' do
      expect(response).not_to be_unavailable
      expect(response.response_available_at).to be_nil
    end

    # Refusing the message over its date would settle as unreadable an exchange
    # the announcement exists to keep from failing.
    it 'answers nil for a date that cannot be read' do
      unreadable = with_deferral { |body| body.sub('2026-08-07T10:00:00.000Z', 'la semaine prochaine') }

      expect(unreadable.response_available_at).to be_nil
      expect(unreadable).to be_unavailable
    end

    # `R-EDM-RESP-S014` forbids the slot to any status but this one, so the
    # reading answers nothing for a response that carries it against the rule.
    it 'answers nil on a response that carries the slot without the status' do
      contradictory = with_deferral do |body|
        body.sub('ResponseStatusType:Unavailable', 'ResponseStatusType:Success')
      end

      expect(contradictory).not_to be_unavailable
      expect(contradictory.response_available_at).to be_nil
    end

    # `Time.zone.iso8601` rolls a day that does not exist into the next month.
    # A date invented on a correspondent's behalf is worse than none.
    it 'answers nil for a day that does not exist, rather than the day after' do
      impossible = with_deferral { |body| body.sub('2026-08-07T10:00:00.000Z', '2026-02-30T10:00:00.000Z') }

      expect(impossible.response_available_at).to be_nil
    end

    it 'answers nil when the slot is absent altogether' do
      stripped = with_deferral do |body|
        body.sub(%r{<rim:Slot name="ResponseAvailableDateTime">.*?</rim:Slot>}m, '')
      end

      expect(stripped.response_available_at).to be_nil
    end

    def with_deferral
      document = Nokogiri::XML(built_envelope('reponseDifferee'))
      value = document.xpath('//payload/value').first
      value.content = Base64.strict_encode64(yield(Base64.decode64(value.text)))

      RetrievedMessageParser.new(document.to_xml).body
    end
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
