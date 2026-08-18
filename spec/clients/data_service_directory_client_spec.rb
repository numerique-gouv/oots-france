require 'rails_helper'

RSpec.describe DataServiceDirectoryClient do
  subject(:directory) { described_class.new(query:) }

  let(:query) { instance_double(CommonServicesQuery) }
  let(:classification) { 'https://sr.acc.oots.tech.ec.europa.eu/evidencetypeclassifications/FI/19f0783e' }

  before do
    allow(query).to receive(:search)
      .and_return(DataServicesResponseParser.new(common_services_answer('dsd_data_services_fi').first))
  end

  it 'asks which data services hold that evidence type in that country' do
    expect(directory.data_services(evidence_type_classification: classification, country_code: 'FI').size).to eq(1)
  end

  # The same answer read two ways: what the message needs is the organisation
  # and its access point, what an operator reads is the pairing the directory
  # published.
  it 'answers the organisations holding it, from the same query' do
    providers = directory.providers(evidence_type_classification: classification, country_code: 'FI')

    expect(providers.map { |provider| provider.identifier.id }).to eq(['FIKEHA02'])
  end

  # Version negotiation happens at the directory rather than here: the service
  # returns only the access services declaring that `ConformsTo`, so an empty
  # answer means no correspondent speaks what we produce. Chapter 3.1.4.
  it 'restricts the answer to the exchange version we are able to produce' do
    directory.data_services(evidence_type_classification: classification, country_code: 'FI')

    expect(query).to have_received(:search).with(
      {
        queryId: described_class::DATA_SERVICES_QUERY,
        'evidence-type-classification': classification,
        'country-code': 'FI',
        specification: EdmSpecification::IDENTIFIER,
      },
      parser: DataServicesResponseParser,
    )
  end
end
