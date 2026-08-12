require 'rails_helper'

RSpec.describe Directories::EvidenceRequesters do
  subject(:directory) { described_class.new(data) }

  let(:data) do
    { '00000000000002' => { 'nom' => 'Requêteur de test', 'url' => 'http://localhost:4000' } }
  end

  it 'resolves a SIRET to the requester it designates' do
    expect(directory.find('00000000000002'))
      .to have_attributes(name: 'Requêteur de test', url: 'http://localhost:4000')
  end

  it 'gives the requester the French SIRET scheme' do
    expect(directory.find('00000000000002').type_id).to eq(IdentifierScheme::FRENCH)
  end

  it 'raises on a SIRET absent from the directory' do
    expect { directory.find('00000000000003') }
      .to raise_error(EvidenceRequesterNotFound, /00000000000003/)
  end
end
