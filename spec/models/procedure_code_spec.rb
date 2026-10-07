require 'rails_helper'

# What the specification publishes, as against what a request may name: a code
# outside the list and other than `00` breaks `R-EDM-REQ-C003`, a FATAL rule.
RSpec.describe ProcedureCode do
  describe 'what the specification publishes' do
    it 'holds the codes of the published list' do
      expect(described_class::PUBLISHED).to include('T1', 'R1', 'T3')
    end

    # `R-EDM-REQ-C003` admits it beside the list rather than in it — « For
    # testing purposes the code '00' can be used ».
    it 'leaves the system check beside the list, where the rule puts it' do
      expect(described_class::PUBLISHED).not_to include(described_class::SYSTEM_CHECK)
    end
  end

  describe 'what the demonstration may play' do
    it 'is the list, then the system check' do
      expect(described_class::ADMITTED).to eq([*described_class::PUBLISHED, '00'])
      expect(described_class).to be_admitted('00')
      expect(described_class).not_to be_admitted('Z9')
    end
  end

  # Stub, tracked as OOTS-82: the announcement of chapter 4.5.2 has to be
  # produced somewhere.
  it 'defers the registration of a birth, and nothing else' do
    expect(described_class).to be_deferred(described_class::BIRTH_REGISTRATION)
    expect(described_class).not_to be_deferred(described_class::STUDY_FINANCING)
  end
end
