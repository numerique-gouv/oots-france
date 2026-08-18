require 'rails_helper'

RSpec.describe 'Admin::CommonServices::Catalogue' do
  before do
    sign_in
    stub_code_list
    stub_directory_resolution
    stub_directory('eb', 'requirements-by-procedure', 'eb_requirements_catalogue')
  end

  it 'counts what the Evidence Broker publishes' do
    get admin_common_services_root_path

    expect(response.body).to include('22 codes de démarche', '27 pays', '53 exigences')
  end

  # The count reads on its own everywhere else, so it is capitalised; sewn into
  # the middle of a sentence it would carry that capital in with it.
  it 'sews the country count into the sentence without its capital' do
    stub_directory('eb', 'requirements-by-procedure', 'eb_requirements_fr')

    get admin_common_services_root_path

    expect(response.body).to include('par un pays')
    expect(response.body).not_to include('par Un pays')
  end

  it 'leads to both listings' do
    get admin_common_services_root_path

    expect(response.parsed_body.css("a[href='#{admin_common_services_procedures_path}']")).to be_present
    expect(response.parsed_body.css("a[href='#{admin_common_services_requirements_path}']")).to be_present
  end

  # The Data Service Directory demands both its evidence type and its country:
  # there is no list of providers to offer, and the page says so rather than
  # leaving one to look for it.
  it 'says why providers cannot be listed' do
    get admin_common_services_root_path

    expect(response.body).to include('Data Service Directory')
  end

  it 'opens the administration space onto the directories' do
    get admin_root_path

    expect(response.parsed_body.css("a[href='#{admin_common_services_root_path}']")).to be_present
  end
end
