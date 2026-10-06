require 'rails_helper'

# The test environment schedules nothing, so nothing else in the suite reads
# the deployed schedule: a class renamed there would leave a sweep that never
# runs — the one that closes connectivity tests past their deadline among them.
RSpec.describe 'config/schedule.yml' do
  let(:schedule) { Rails.application.config_for(:schedule, env: 'production') }

  it 'names a job that exists for every entry' do
    schedule.each_value do |entry|
      expect(entry[:class].constantize).to be < ApplicationJob
      expect(Fugit.parse_cron(entry[:cron])).to be_present
    end
  end

  it 'sweeps the connectivity tests' do
    expect(schedule.values.pluck(:class)).to include('ReadConnectivityVerdictsJob')
  end
end
