require 'rails_helper'

RSpec.describe 'Admin::CommonServices::Providers' do
  let(:test_requirement) { '00000000-0000-0000-0000-000000000000' }
  let(:finnish_type) { '19f0783e-7cdc-4146-9ff9-e331514ffb74' }

  before do
    sign_in
    stub_code_list
    stub_directory_resolution
    stub_directory('eb', 'requirements-by-procedure', 'eb_requirements_catalogue')
    stub_directory('eb', 'evidence-types-by-requirement', 'eb_evidence_types_fi')
    stub_directory('dsd', 'dataservices-by-evidencetype', 'dsd_data_services_fi')
  end

  def visit_providers(type: nil)
    get admin_common_services_requirement_evidence_type_providers_path(test_requirement, type || finnish_type)
  end

  # The publisher names the organisation holding the evidence, the access
  # service the gateway carrying messages to it: conflating them is the mistake
  # the page must not invite.
  it 'tells the provider apart from the access point reaching it' do
    visit_providers

    expect(response.body).to include('Keha v. 2.0', 'FIKEHA02', 'AP_FI_03')
  end

  # The identifier the directory assigns to the pairing, which an outgoing
  # request writes into its `DataServiceEvidenceType` slot.
  it 'shows what the directory says of the service itself' do
    visit_providers

    expect(response.body).to include('41170824-15d9-4c16-984e-63b75b937b8c', 'Substantial')
  end

  # The console asks the directory exactly as the application does, version
  # parameter included, so a gateway speaking another version is absent from
  # the answer. Showing the versions is what keeps that legible.
  it 'shows the EDM versions the access point declares, and the version asked for' do
    visit_providers

    expect(response.body).to include('oots-edm:v2.0')
    expect(a_request(:get, "#{DirectoryStubs::ACCEPTANCE}/dsd/rest/search")
      .with(query: hash_including('specification' => EdmSpecification::IDENTIFIER))).to have_been_made
  end

  # An evidence type is published by one jurisdiction — its Semantic Repository
  # identifier carries it — so asking another country for it can only come back
  # empty. The country is read off the type rather than left to a filter, which
  # is also how the request path pairs them.
  it 'asks the directory for the country that publishes the type' do
    visit_providers

    expect(a_request(:get, "#{DirectoryStubs::ACCEPTANCE}/dsd/rest/search")
      .with(query: hash_including('country-code' => 'FI',
        'evidence-type-classification' => a_string_including('/FI/')))).to have_been_made
    expect(response.body).to include('en Finlande')
  end

  # « No provider in this country » is the answer the page was opened to get:
  # it belongs beside the question, not on a page of its own.
  it 'shows a refusal in place, keeping the question on screen' do
    stub_directory('dsd', 'dataservices-by-evidencetype', 'dsd_aucun_service_fr')

    visit_providers

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('DSD:ERR:0001', 'Qui délivre')
  end

  # This page keeps its own rescue, to show a refusal in place; an outage has
  # nothing to be shown beside and goes up to the 502 the console renders.
  it 'answers 502 when the Data Service Directory cannot be reached' do
    stub_request(:get, "#{DirectoryStubs::ACCEPTANCE}/dsd/rest/search")
      .with(query: hash_including({})).to_timeout

    visit_providers

    expect(response).to have_http_status(:bad_gateway)
    expect(response.body).to include('Annuaire injoignable')
  end

  # A link kept from another evidence type still carries its country in the
  # address. The list that publishes the type is what decides, failing which the
  # response would come back empty with nothing to say why.
  it 'ignores a country the address still carries' do
    get admin_common_services_requirement_evidence_type_providers_path(
      test_requirement, finnish_type, country_code: 'IT',
    )

    expect(a_request(:get, "#{DirectoryStubs::ACCEPTANCE}/dsd/rest/search")
      .with(query: hash_including('country-code' => 'FI'))).to have_been_made
  end

  it 'answers 404 for an evidence type the requirement does not carry' do
    visit_providers(type: '00000000-0000-0000-0000-999999999999')

    expect(response).to have_http_status(:not_found)
  end
end
