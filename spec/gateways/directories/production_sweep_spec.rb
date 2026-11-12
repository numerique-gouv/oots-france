require 'rails_helper'

RSpec.describe Directories::ProductionSweep do
  subject(:sweep) { described_class.new }

  let!(:resolver) { serve_production_directories }

  # CA5: the deployment exchanges in acceptance, through a proxy; the copy is
  # read from production all the same.
  before do
    allow(Settings).to receive_messages(common_services_environment: 'acc')
    allow(Settings).to receive(:common_services_base_url).and_return('https://mandataire.example')
  end

  it 'records every answer the public page reads, refusals included' do
    expect(sweep.call).to eq(snapshot_answers)
  end

  it 'asks the production instances, found under the `prod` names, and through no proxy' do
    sweep.call

    expect(resolver).to have_received(:getresources).with('fr.eb.v1.cs.prod.oots.tech.ec.europa.eu', anything).at_least(:once)
    expect(resolver).to have_received(:getresources).with('fr.dsd.v1.cs.prod.oots.tech.ec.europa.eu', anything).at_least(:once)
    expect(resolver).not_to have_received(:getresources).with(/\.acc\./, anything)
    expect(a_request(:get, /mandataire/)).not_to have_been_made
  end

  it 'checks every answer against the production trust store' do
    sweep.call

    expect(CommonServicesSignature).to have_received(:new)
      .with(trust_store_path: Rails.root.join('config/certificats/services_communs_prod.pem').to_s).twice
  end

  it 'asks the Data Service Directory once for each evidence type, in the country publishing it' do
    sweep.call

    expect(a_request(:get, "#{DirectorySnapshots::PRODUCTION}/dsd/rest/search")
      .with(query: hash_including('country-code' => 'EL'))).to have_been_made.twice
    expect(a_request(:get, "#{DirectorySnapshots::PRODUCTION}/dsd/rest/search")
      .with(query: hash_including('country-code' => 'FR'))).not_to have_been_made
  end

  # Chapter 3.7 §4: the page never shows them.
  it 'asks the Data Service Directory nothing for the smoke-test requirements' do
    serve_production_directories(snapshot_answers(smoke_tests: true))

    sweep.call

    expect(a_request(:get, %r{/dsd/rest/search})).not_to have_been_made
  end

  it 'keeps a type the Data Service Directory does not know, as the page states it' do
    answers = snapshot_answers(data_services: { '19f0783e' => unknown_evidence_type_answer })
    serve_production_directories(answers)

    expect(sweep.call).to eq(answers)
  end

  it 'raises on any other refusal of the Data Service Directory' do
    refused = common_services_answer('dsd_aucun_service_fr').first.sub('DSD:ERR:0001', 'DSD:ERR:0003')
    serve_production_directories(snapshot_answers(data_services: { '19f0783e' => refused }))

    expect { sweep.call }.to raise_error(CommonServicesError) { |error| expect(error.code).to eq('DSD:ERR:0003') }
  end
end
