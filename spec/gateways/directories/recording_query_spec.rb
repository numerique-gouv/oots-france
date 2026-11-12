require 'rails_helper'

RSpec.describe Directories::RecordingQuery do
  let(:answers) { {} }
  let(:refusal) { common_services_answer('dsd_aucun_service_fr').first }
  let(:live) { instance_double(CommonServicesQuery, read: refusal) }
  let(:parameters) { { queryId: 'q', 'country-code': 'FR' } }

  # A refusal of the Data Service Directory is what the page states: it is kept
  # before the parser raises it.
  it 'keeps the body it read, a refusal included, under the key of the question' do
    query = described_class.new(live, into: answers)

    expect { query.search(parameters, parser: DataServicesResponseParser) }
      .to raise_error(CommonServicesError) { |error| expect(error.code).to eq('DSD:ERR:0001') }
    expect(answers).to eq(DirectorySnapshot::Answer.key(parameters) => refusal)
    expect(live).to have_received(:read).with(parameters)
  end
end
