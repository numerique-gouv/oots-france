require 'rails_helper'

RSpec.describe RefreshDirectorySnapshotJob do
  # CA8
  it 'runs every night with the recurring jobs' do
    schedule = Rails.application.config_for(:schedule, env: 'production')

    expect(schedule.values).to include(a_hash_including(class: 'RefreshDirectorySnapshotJob', cron: '43 2 * * *'))
  end

  it 'takes the copy' do
    allow(DirectorySnapshotting::Take).to receive(:call)

    described_class.perform_now

    expect(DirectorySnapshotting::Take).to have_received(:call)
  end

  # CA7: the copy lives in the database, which the web and the worker share
  # and which outlives a restart.
  it 'writes the copy the web process reads' do
    serve_production_directories

    described_class.perform_now

    expect(DirectorySnapshot.current.answers.count).to eq(snapshot_answers.size)
  end
end
