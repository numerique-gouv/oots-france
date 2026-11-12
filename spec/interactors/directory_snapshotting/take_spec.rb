require 'rails_helper'

RSpec.describe DirectorySnapshotting::Take do
  let(:night) { Time.zone.local(2026, 11, 9, 2, 43) }
  let(:clock) { instance_double(Clock, now: night) }
  let(:previous) { take_snapshot(taken_at: night - 1.day) }

  before do
    serve_production_directories
    previous
  end

  it 'replaces the copy by the one the production directories answer' do
    expect(described_class.call(clock:)).to be_success

    expect(DirectorySnapshot.current.taken_at).to eq(night)
    expect(DirectorySnapshot.current.answers.count).to eq(snapshot_answers.size)
  end

  # CA8
  shared_examples 'a failed update' do |detail|
    it 'leaves the copy and its date as they were, and records why' do
      expect(described_class.call(clock:)).to be_failure

      expect(DirectorySnapshot.current).to eq(previous)
      expect(DirectorySnapshot.current.taken_at).to eq(night - 1.day)
      expect(DirectorySnapshot.last_failure).to have_attributes(failed_at: night, **detail)
    end
  end

  context 'when the production trust store cannot be read' do
    before do
      allow(CommonServicesSignature).to receive(:new).and_return(instance_double(CommonServicesSignature))
      allow(CommonServicesSignature.new).to receive(:verify!).and_raise(ConfigurationError, 'Truststore illisible')
    end

    it_behaves_like 'a failed update', failure_code: nil, failure_detail: 'Truststore illisible'
  end

  context 'when an answer is not signed by production' do
    before do
      allow(CommonServicesSignature).to receive(:new).and_return(instance_double(CommonServicesSignature))
      allow(CommonServicesSignature.new).to receive(:verify!).and_raise(CommonServicesError, 'Signature invalide')
    end

    it_behaves_like 'a failed update', failure_code: nil, failure_detail: 'Signature invalide'
  end

  # Raised by no client as a `CommonServicesError`: a resolver timing out.
  context 'when the sweep fails on an error no client converts' do
    let(:sweep) { instance_double(Directories::ProductionSweep) }

    before { allow(sweep).to receive(:call).and_raise(Resolv::ResolvTimeout, 'délai DNS') }

    it 'records it, leaves the copy, and raises it again' do
      expect { described_class.call(clock:, sweep:) }.to raise_error(Resolv::ResolvTimeout)

      expect(DirectorySnapshot.current).to eq(previous)
      expect(DirectorySnapshot.last_failure).to have_attributes(failed_at: night, failure_code: nil,
        failure_detail: 'Resolv::ResolvTimeout: délai DNS')
    end
  end

  context 'when the Evidence Broker is unreachable' do
    before { stub_request(:get, %r{/eb/rest/search}).to_timeout }

    it_behaves_like 'a failed update', failure_code: nil
  end

  context 'when the Data Service Directory is unreachable for one country' do
    before do
      stub_request(:get, %r{/dsd/rest/search}).with(query: hash_including('country-code' => 'FI')).to_timeout
    end

    it_behaves_like 'a failed update', failure_code: nil
  end

  context 'when the Data Service Directory refuses one country by another code' do
    before do
      refused = common_services_answer('dsd_aucun_service_fr').first.sub('DSD:ERR:0001', 'DSD:ERR:0003')
      serve_production_directories(snapshot_answers(data_services: { '19f0783e' => refused }))
    end

    it_behaves_like 'a failed update', failure_code: 'DSD:ERR:0003'
  end
end
