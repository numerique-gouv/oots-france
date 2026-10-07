require 'rails_helper'

# RG14 of OOTS-253: France serves on the evidence type
# asked for, whatever the procedure. Stub, tracked as OOTS-82.
RSpec.describe ServedEvidenceType do
  def type(id) = build(:evidence_type, id:)

  it 'serves the two types France declares, under either host of the Semantic Repository' do
    expect(described_class).to be_served(type(Fixtures::SERVED_TYPE))
    expect(described_class)
      .to be_served(type('https://sr.oots.tech.ec.europa.eu/evidencetypeclassifications/FR/9bc466ca-d785-4b20-a5e2-0da1c0b9e931'))
  end

  it 'serves no type of another member state' do
    expect(described_class).not_to be_served(type(Fixtures::UNSERVED_TYPE))
  end
end
