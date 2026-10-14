require 'rails_helper'

# The list the Greek `DSD:ERR:0005` addresses on the acceptance environment,
# captured as it answers: `text/plain`, eight codes, no `name-EN`.
RSpec.describe ClassificationValuesClient do
  subject(:client) { described_class.new }

  let(:address) do
    'https://query.cs.acc.oots.tech.ec.europa.eu/codelists/EL/ProjectathonTestCases/8b3b6a31-9b62-48d7-8926-997df4f91bb5'
  end
  let(:list) { Rails.root.join('spec/fixtures/common_services/liste_classification_el_projectathon.gc').read }

  before { stub_request(:get, address).to_return(body: list, headers: { 'Content-Type' => 'text/plain;charset=UTF-8' }) }

  it 'offers each code under its name-Value, the list carrying no name in the language asked' do
    values = client.values(address, language: 'EN')

    expect(values.size).to eq(8)
    expect(values.first).to eq(['TC03 - Evidence request error flow due to Basic Registry error', 'TC03'])
  end

  it 'names each code in the language asked where the list carries it' do
    expect(client.values(address, language: 'EL').first.first).to start_with('TC03 - Ανεπιτυχής')
  end

  # « deprecated: indicates that the value is no longer active ».
  it 'leaves out a deprecated code' do
    stub_request(:get, address).to_return(body: list.sub('<SimpleValue>false</SimpleValue>', '<SimpleValue>true</SimpleValue>'))

    expect(client.values(address, language: 'EN').map(&:last)).not_to include('TC03')
  end

  # « the lifespan of the URI is therefore limited to the DSD request ».
  it 'reads the list again at each call' do
    2.times { client.values(address, language: 'EN') }

    expect(a_request(:get, address)).to have_been_made.twice
  end

  describe 'a list that cannot be read' do
    it 'answers nothing on an error' do
      stub_request(:get, address).to_return(status: 503)

      expect(client.values(address, language: 'EN')).to be_nil
    end

    it 'answers nothing on a body that is no code list' do
      stub_request(:get, address).to_return(body: '<html>maintenance</html>')

      expect(client.values(address, language: 'EN')).to be_nil
    end

    # `R-DSD-ERR-C038` (FATAL).
    it 'follows no address that is not https' do
      expect(client.values(address.sub('https', 'http'), language: 'EN')).to be_nil
      expect(a_request(:get, /codelists/)).not_to have_been_made
    end
  end
end
