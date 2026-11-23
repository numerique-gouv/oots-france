require 'rails_helper'

# RG14 of OOTS-253: France serves on the evidence type
# asked for, whatever the procedure.
RSpec.describe ServedEvidenceType do
  def type(id) = build(:evidence_type, id:)

  it 'serves the two types France declares to serve, under either host of the Semantic Repository' do
    expect(described_class).to be_served(type(Fixtures::SERVED_TYPE))
    expect(described_class)
      .to be_served(type('https://sr.oots.tech.ec.europa.eu/evidencetypeclassifications/FR/9bc466ca-d785-4b20-a5e2-0da1c0b9e931'))
  end

  it 'serves no type of another member state' do
    expect(described_class).not_to be_served(type(Fixtures::UNSERVED_TYPE))
  end

  it 'serves the type no document matches, and tells it apart' do
    unmatched = type(Fixtures::UNMATCHED_TYPE)

    expect(described_class).to be_served(unmatched)
    expect(described_class).to be_unmatched(unmatched)
    expect(described_class).not_to be_unmatched(type(Fixtures::SERVED_TYPE))
  end

  # RG1 of OOTS-311.
  it 'serves the type whose preview waives the re-authentication, and tells it apart' do
    waived = type(Fixtures::REAUTHENTICATION_WAIVED_TYPE)

    expect(described_class).to be_served(waived)
    expect(described_class).to be_reauthentication_waived(waived)
    [Fixtures::SERVED_TYPE, Fixtures::UNMATCHED_TYPE, Fixtures::UNSERVED_TYPE].each do |other|
      expect(described_class).not_to be_reauthentication_waived(type(other))
    end
  end

  describe '.distribution_for' do
    def asking(id, *formats) = build(:evidence_type, id:, distribution_formats: formats)

    let(:student_status) { ApiParticulierStubs::STUDENT_STATUS_TYPE }

    it 'serves the student status as data where the request asks for JSON, alone or beside the PDF' do
      expect(described_class.distribution_for(asking(student_status, 'application/json'))).to eq(StudentStatus::DATA)
      expect(described_class.distribution_for(asking(student_status, 'application/json', EvidenceType::PDF)))
        .to eq(StudentStatus::DATA)
      expect(described_class.distribution_for(asking(student_status, EvidenceType::PDF, 'application/json')))
        .to eq(StudentStatus::DATA)
    end

    it 'serves the attestation where the request asks for the PDF alone' do
      expect(described_class.distribution_for(asking(student_status, EvidenceType::PDF)))
        .to eq(StudentStatus::ATTESTATION)
    end

    it 'serves nothing the request does not ask for' do
      expect(described_class.distribution_for(asking(student_status, 'application/xml'))).to be_nil
      expect(described_class.distribution_for(asking(Fixtures::SERVED_TYPE, 'application/json'))).to be_nil
    end

    it 'serves the test types in their PDF' do
      expect(described_class.distribution_for(asking(Fixtures::SERVED_TYPE, EvidenceType::PDF)))
        .to eq(ServedDistribution::PDF)
      expect(described_class.distribution_for(asking(Fixtures::REAUTHENTICATION_WAIVED_TYPE, EvidenceType::PDF)))
        .to eq(ServedDistribution::PDF)
    end
  end
end
