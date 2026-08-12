require 'rails_helper'

RSpec.describe EvidenceRequest::ResolveRequester do
  subject(:resolve) { described_class.call(requester_id: '00000000000002', requesters:) }

  let(:requesters) do
    Directories::EvidenceRequesters.new(
      '00000000000002' => { 'nom' => 'Requêteur', 'url' => 'http://localhost:4000' },
    )
  end

  # The whole answer is handed back to this URL, so an exchange opened against
  # the wrong entry would deliver a citizen's evidence to the wrong provider.
  it 'resolves the service provider the identifier names' do
    expect(resolve.requester).to have_attributes(id: '00000000000002', url: 'http://localhost:4000')
  end

  describe 'an identifier the directory does not hold' do
    subject(:resolve) { described_class.call(requester_id: '00000000000009', requesters:) }

    # Structured rather than raised: the caller is at fault here, and a step
    # that fails like its five neighbours lets the controller answer like it
    # answers them.
    it 'fails, naming the identifier that was not found' do
      expect(resolve).to be_failure
      expect(resolve.error).to include(key: :unknown_requester)
      expect(resolve.error[:errors].first).to include('00000000000009')
    end
  end
end
