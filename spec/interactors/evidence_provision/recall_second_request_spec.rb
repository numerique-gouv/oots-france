require 'rails_helper'

RSpec.describe EvidenceProvision::RecallSecondRequest do
  # A job arriving after the session was concluded, or destroyed at T2 + T3,
  # has nothing to answer.
  it 'fails quietly on a session holding no second request' do
    expect(described_class.call(preview_session_id: create(:preview_session).id)).to be_failure
  end

  it 'fails quietly on a session that no longer exists' do
    expect(described_class.call(preview_session_id: 0)).to be_failure
  end
end
