require 'rails_helper'

RSpec.describe 'Admin::CommonServices::Providers' do
  let(:test_requirement) { '00000000-0000-0000-0000-000000000000' }
  let(:finnish_type) { '19f0783e-7cdc-4146-9ff9-e331514ffb74' }
  let(:data_model) { 'https://sr.acc.oots.tech.ec.europa.eu/datamodels/SDG-CertificateOfBirth' }
  let(:published) { common_services_answer('dsd_data_services_fi').first }
  let(:undistributed) { published.sub(%r{<sdg:DistributedAs>.*?</sdg:DistributedAs>}m, '') }
  let(:structured) do
    published.sub('<sdg:Format>application/pdf</sdg:Format>', '<sdg:Format>application/xml</sdg:Format>')
  end
  let(:modelled) do
    structured.sub('</sdg:DistributedAs>', "<sdg:ConformsTo>#{data_model}</sdg:ConformsTo></sdg:DistributedAs>")
  end
  let(:waived) do
    structured.sub('</sdg:DistributedAs>',
      '</sdg:DistributedAs><sdg:DistributedAs><sdg:Format>application/pdf</sdg:Format></sdg:DistributedAs>')
  end

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

  # R-DSD-RESP-S027 (FATAL) makes `sdg:DistributedAs` mandatory, so a service
  # published without one is an anomaly of the directory. The acceptance
  # environment holds none — its thirteen answers all carry a distribution — so
  # the answer is built here, and its signature doubled: the captures are signed
  # over their bytes and none of them can be edited.
  it 'names a distribution the directory published nothing of' do
    stub_directory_signature
    stub_directory_body('dsd', 'dataservices-by-evidencetype', undistributed)

    visit_providers

    expect(response.body).to include('Aucune distribution publiée', 'R-DSD-RESP-S027')
  end

  # The data model of the distribution (R-DSD-RESP-C010) and the EDM versions of
  # the access point (R-DSD-RESP-C015) are two elements under two parents, and
  # the page must not let them be read as one: the two labels share no word.
  it 'names the data model of the distribution apart from the access point versions' do
    stub_directory_signature
    stub_directory_body('dsd', 'dataservices-by-evidencetype', modelled)

    visit_providers

    expect(response.body).to include('Modèle de données', data_model, 'versions déclarées')
  end

  # The same empty value, and two opposite verdicts. C039 makes the data model
  # mandatory beside an XML distribution published without an unstructured one,
  # and the acceptance environment holds no such entry: like the badge above,
  # this state is only ever seen in a spec — a console is written for the case
  # one hopes not to meet.
  it 'accuses the directory where the rules require a data model it did not publish' do
    stub_directory_signature
    stub_directory_body('dsd', 'dataservices-by-evidencetype', structured)

    visit_providers

    expect(response.body).to include('Modèle de données manquant', 'R-DSD-RESP-C039')
  end

  # C039 and C041 excuse the distribution when the record publishes an
  # unstructured one too, which is what the Irish entries of the acceptance
  # environment do: nothing is missing there, and a dash would say otherwise.
  it 'names the data model unowed where an unstructured distribution is published too' do
    stub_directory_signature
    stub_directory_body('dsd', 'dataservices-by-evidencetype', waived)

    visit_providers

    expect(response.body).to include('Modèle de données non exigé', 'R-DSD-RESP-C039')
    expect(response.body).not_to include('Modèle de données manquant')
  end

  # R-DSD-RESP-C067 forbids the value beside an unstructured distribution, and
  # the captured Finnish answer publishes a PDF: an empty line there would
  # announce a gap the rule itself creates.
  it 'leaves the data model off a distribution the rules forbid one on' do
    visit_providers

    expect(response.body).to include('application/pdf')
    expect(response.body).not_to include('Modèle de données')
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
