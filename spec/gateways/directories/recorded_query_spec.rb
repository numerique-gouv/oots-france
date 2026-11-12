require 'rails_helper'

RSpec.describe Directories::RecordedQuery do
  let(:snapshot) { take_snapshot }

  it 'answers the Evidence Broker from the copy, through its parser' do
    client = EvidenceBrokerClient.new(query: described_class.new(snapshot))

    expect(client.requirements.map(&:label)).to contain_exactly('(TEST) Test Requirement', '(TEST) Test Requirement 2')
  end

  it 'replays a refusal it kept, with its code' do
    client = EvidenceBrokerClient.new(query: described_class.new(snapshot))

    expect { client.evidence_type_lists(requirement_id: DirectorySnapshots::EMPTY_REQUIREMENT) }
      .to raise_error(CommonServicesError) { |error| expect(error.code).to eq('EB:ERR:0001') }
  end
end
