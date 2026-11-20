require 'rails_helper'

RSpec.describe Demo::Request do
  subject(:request) do
    described_class.new(exchange_id: 'echange-1', conversation_id: 'conversation-1',
      journey_id: 'parcours-1', requirement_uuid: '00000000-0000-0000-0000-000000000000', country_code: 'FI',
      specification: EdmSpecification::V1_2, procedure_code: 'T1')
  end

  it { is_expected.to validate_presence_of(:exchange_id) }
  it { is_expected.to validate_presence_of(:conversation_id) }
  # The two a zone finds its own request by, and `null: false` in the table
  # like the pair above.
  it { is_expected.to validate_presence_of(:journey_id) }
  it { is_expected.to validate_presence_of(:requirement_uuid) }
  # The member state the request was addressed to, which its card stays in
  # while the request is under way.
  it { is_expected.to validate_presence_of(:country_code) }
  # The line the journey asked it in.
  it { is_expected.to validate_presence_of(:specification) }
  # The procedure the journey plays.
  it { is_expected.to validate_presence_of(:procedure_code) }

  describe '.previewed_at' do
    let(:location) { 'https://oots.example/previsualisation/v1.2/jeton' }

    def previewed(address, journey_id: 'parcours-1')
      registered_request(SecureRandom.uuid, journey_id:, preview_address: address)
    end

    def found = described_class.previewed_at(journey_id: 'parcours-1', location:)

    it 'finds the request of the journey whose link is the address' do
      expected = previewed(location)

      expect(found).to eq([expected])
    end

    # Chapter 4.9 v1.2.3 §5: the way back appended to the address for a GET.
    it 'finds it under the way back the 1.2 line appends' do
      expected = previewed("#{location}?returnurl=https%3A%2F%2Fportail.example&returnmethod=GET")

      expect(found).to eq([expected])
    end

    it 'finds neither another journey nor another address' do
      previewed(location, journey_id: 'parcours-2')
      previewed("#{location}-autre")
      previewed('https://oots.example/previsualisation/v1.2/jetons')

      expect(found).to be_empty
    end
  end

  describe '#answers?' do
    # Chapter 4.4 §4.3.2 gives each identifier its own job, so both are asked of
    # a delivery.
    it 'recognises a delivery naming both of its identifiers' do
      expect(request.answers?('echange-1', 'conversation-1')).to be(true)
    end

    it 'refuses one naming its exchange under another conversation' do
      expect(request.answers?('echange-1', 'conversation-2')).to be(false)
    end
  end

  describe '#receive_evidence!' do
    let(:content) { "%PDF-1.4\ndrapeau".b }

    before { request.save! }

    # Chapter 1 §4.2: the user « cannot modify its content in any way », so what
    # is filed is what arrived, and the digest is taken of those same bytes.
    it 'files the bytes as they arrived, with their digest' do
      request.receive_evidence!(content, EvidenceType::PDF)

      expect(request.reload.evidence).to eq(content)
      expect(request).to have_attributes(evidence_digest: Digest::SHA256.hexdigest(content),
        evidence_mime_type: EvidenceType::PDF)
    end

    # Only a PDF opens in place: any other type comes from a correspondent, and
    # opened under the console's origin an SVG or an XML would run there.
    it 'opens a PDF alone in place, and names the extension of its type' do
      request.receive_evidence!(content, EvidenceType::PDF)
      expect(request).to have_attributes(evidence_opens_in_place?: true, evidence_extension: 'pdf')

      request.receive_evidence!('<svg/>', 'image/svg+xml')
      expect(request).to have_attributes(evidence_opens_in_place?: false, evidence_extension: 'svg')
    end

    it 'is what makes the request one that has its evidence' do
      expect { request.receive_evidence!(content, EvidenceType::PDF) }.to change(request, :evidence?).from(false).to(true)
    end
  end
end
