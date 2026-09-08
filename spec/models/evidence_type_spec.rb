require 'rails_helper'

RSpec.describe EvidenceType do
  it { is_expected.to validate_presence_of(:id) }

  # `pdf?` is what decides whether France serves at all —
  # `EvidenceProvision::ChooseAnswer` reads it and nothing else to choose
  # between the document and `EDM:ERR:0007`.
  describe '#pdf?' do
    it 'is true of a type distributed as the one document France holds' do
      expect(build(:evidence_type)).to be_pdf
    end

    # `R-EDM-REQ-C032` admits several distributions, and chapter 4.5.1 §3.5
    # names the case: a human-readable format beside a structured one. France
    # holds one document, so it answers as soon as the PDF is among them.
    it 'is true whatever rank the PDF holds among the formats asked for' do
      expect(build(:evidence_type, distribution_formats: ['application/xml', described_class::PDF])).to be_pdf
      expect(build(:evidence_type, distribution_formats: [described_class::PDF, 'application/xml'])).to be_pdf
    end

    it 'is false when none of the formats asked for is the one served' do
      expect(build(:evidence_type, distribution_formats: ['application/xml', 'image/png'])).not_to be_pdf
    end

    # What a `sdg:DistributedAs` naming no format reads as. The rule counts the
    # element and says nothing of its content, so this type is conformant and
    # simply asks for nothing France serves.
    it 'is false of a distribution that named no format at all' do
      expect(build(:evidence_type, distribution_formats: [nil])).not_to be_pdf
    end
  end

  # The Evidence Broker publishes no format for an unstructured evidence type,
  # and the rest of the chain expects one.
  it 'falls back on the single document this deployment serves' do
    expect(build(:evidence_type, distribution_formats: nil).distribution_formats).to eq([described_class::PDF])
  end

  # Presence on the collection, and nothing more: a nil entry is what a
  # conformant request can carry, where an empty collection is what
  # `R-EDM-REQ-C032` refuses.
  describe 'the distributions it carries' do
    it 'refuses a type carrying no distribution at all' do
      expect(build(:evidence_type, distribution_formats: [])).not_to be_valid
    end

    it 'accepts one whose distribution named no format' do
      expect(build(:evidence_type, distribution_formats: [nil])).to be_valid
    end
  end
end
