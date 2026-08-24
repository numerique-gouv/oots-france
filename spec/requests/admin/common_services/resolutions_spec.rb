require 'rails_helper'

RSpec.describe 'Admin::CommonServices::Resolutions' do
  before do
    sign_in
    stub_code_list
    stub_directory_resolution
    stub_directory('eb', 'requirements-by-procedure', 'eb_requirements_fr')
    stub_directory('eb', 'evidence-types-by-requirement', 'eb_evidence_types_fi')
    stub_directory('dsd', 'dataservices-by-evidencetype', 'dsd_data_services_fi')
  end

  # The page opens on a form, and nothing goes out until both halves of the
  # question are named.
  it 'asks the directories nothing until a procedure and a country are given' do
    get admin_common_services_resolution_path

    expect(response.body).to include('Résoudre')
    expect(a_request(:get, "#{DirectoryStubs::ACCEPTANCE}/eb/rest/search")
      .with(query: hash_including({}))).not_to have_been_made
  end

  it 'walks the three steps a request would walk' do
    get admin_common_services_resolution_path(procedure_code: '00', country_code: 'FI')

    expect(response.body).to include('(TEST) Test Requirement', 'Dummy PDF - FI', 'AP_FI_03', 'FIKEHA02')
  end

  # A procedure is ours, the evidence types are the asked country's. Swapping
  # the two is the mistake this page exists to make visible, so it must send
  # what a request sends.
  it 'reads the requirements at home and the evidence types in the country asked' do
    get admin_common_services_resolution_path(procedure_code: '00', country_code: 'FI')

    expect(a_request(:get, "#{DirectoryStubs::ACCEPTANCE}/eb/rest/search")
      .with(query: hash_including('procedure-id' => '00', 'country-code' => 'FR'))).to have_been_made
    expect(a_request(:get, "#{DirectoryStubs::ACCEPTANCE}/eb/rest/search")
      .with(query: hash_including('requirement-id' => a_string_including('requirements'),
        'country-code' => 'FI'))).to have_been_made
  end

  # The whole point of the page: a refusal at the last step must not take the
  # two answers already obtained off the screen.
  it 'keeps the steps already answered when the last one refuses' do
    stub_directory('dsd', 'dataservices-by-evidencetype', 'dsd_aucun_service_fr')

    get admin_common_services_resolution_path(procedure_code: '00', country_code: 'FR')

    expect(response.body).to include('DSD:ERR:0001', '(TEST) Test Requirement', 'Dummy PDF - FI')
  end

  # An alert floating above the three steps leaves the reader to work out which
  # of them stopped: it belongs where the answer would have been.
  it 'shows the refusal at the step that met it, under its own heading' do
    stub_directory('dsd', 'dataservices-by-evidencetype', 'dsd_aucun_service_fr')

    get admin_common_services_resolution_path(procedure_code: '00', country_code: 'FR')
    body = response.body

    expect(body).to include('3. Qui le délivre')
    expect(body.index('3. Qui le délivre')).to be < body.index('DSD:ERR:0001')
    expect(body.index('2. Ce qui satisfait cette exigence')).to be < body.index('3. Qui le délivre')
  end

  it 'names the step that refused even when it is the first' do
    stub_directory('eb', 'requirements-by-procedure', 'eb_requirements_vides')

    get admin_common_services_resolution_path(procedure_code: 'T3', country_code: 'FR')
    body = response.body

    expect(body.index('1. Ce que la démarche exige')).to be < body.index('EB:ERR:0001')
    expect(body).not_to include('2. Ce qui satisfait cette exigence')
  end

  # An outage is not a refusal, and must not read as one on the very page an
  # operator opens to diagnose one. Whichever step meets it: the chain hands it
  # up untouched, and nothing about that depends on where in the chain it sits.
  it 'answers 502 when the last step cannot be reached' do
    stub_request(:get, "#{DirectoryStubs::ACCEPTANCE}/dsd/rest/search")
      .with(query: hash_including({})).to_timeout

    get admin_common_services_resolution_path(procedure_code: '00', country_code: 'FI')

    expect(response).to have_http_status(:bad_gateway)
    expect(response.body).to include('Annuaire injoignable')
  end

  it 'answers 502 when the middle step cannot be reached' do
    stub_request(:get, "#{DirectoryStubs::ACCEPTANCE}/eb/rest/search")
      .with(query: hash_including('queryId' => a_string_including('evidence-types-by-requirement'))).to_timeout

    get admin_common_services_resolution_path(procedure_code: '00', country_code: 'FI')

    expect(response).to have_http_status(:bad_gateway)
  end

  it 'reports a procedure the Evidence Broker does not know' do
    stub_directory('eb', 'requirements-by-procedure', 'eb_requirements_vides')

    get admin_common_services_resolution_path(procedure_code: 'T3', country_code: 'FR')

    expect(response.body).to include('EB:ERR:0001')
  end

  it 'names the step that refused when it is the one in the middle' do
    stub_directory('eb', 'evidence-types-by-requirement', 'eb_requirements_vides')

    get admin_common_services_resolution_path(procedure_code: '00', country_code: 'FI')
    body = response.body

    expect(body.index('2. Ce qui satisfait cette exigence')).to be < body.index('EB:ERR:0001')
    expect(body).to include('(TEST) Test Requirement')
    expect(body).not_to include('3. Qui le délivre')
  end

  it 'says a country it cannot read is unreadable rather than asking with it' do
    get admin_common_services_resolution_path(procedure_code: '00', country_code: 'Finlande')

    expect(response.parsed_body.css('.fr-alert--error')).to be_present
    expect(a_request(:get, "#{DirectoryStubs::ACCEPTANCE}/eb/rest/search")
      .with(query: hash_including({}))).not_to have_been_made
  end

  # An operator following a failed exchange arrives with the form filled in.
  # These pages send queries out to the Commission's directories: the console's
  # guard holds for them as for the rest.
  it 'asks the directories nothing at all without a session' do
    reset!

    get admin_common_services_resolution_path(procedure_code: '00', country_code: 'FI')

    expect(response).to redirect_to(new_admin_session_path)
    expect(a_request(:get, "#{DirectoryStubs::ACCEPTANCE}/eb/rest/search")
      .with(query: hash_including({}))).not_to have_been_made
  end

  it 'is reached from an exchange, carrying its procedure and its country' do
    exchange = create(:exchange, :failed, procedure_code: '00', country_code: 'FI')

    get admin_journal_exchange_path(exchange.exchange_id)

    expect(response.parsed_body.css("a[href*='#{admin_common_services_resolution_path}']")).to be_present
    # The procedure belongs to the country that requests, so to France here, and
    # not to the correspondent the evidence is asked of.
    expect(response.parsed_body.css("a[href='#{admin_common_services_procedure_country_path('00', 'FR')}']"))
      .to be_present
  end
end
