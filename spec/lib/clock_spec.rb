require 'rails_helper'

RSpec.describe Clock do
  include ActiveSupport::Testing::TimeHelpers

  before { travel_to(Time.utc(2026, 9, 14, 13, 3, 27.123)) }

  # A `Time` and not the string the messages carry: one reading serves the
  # `IssueDateTime` slot of a response, in UTC, and the document that response
  # dates, in Paris time.
  it 'reads an instant' do
    expect(described_class.new.now).to be_a(Time).and eq(Time.current)
  end

  it 'reads it in the zone the application runs in' do
    expect(described_class.new.now.time_zone).to eq(Time.zone)
  end

  # The form the messages write it in, which `ApplicationBuilder` holds for all
  # of them: UTC, to the millisecond. Built from an instant of its own rather
  # than from the clock, `travel_to` moving time to the whole second.
  it 'is written into a message in UTC, to the millisecond' do
    builder = Class.new(ApplicationBuilder) do
      def initialize(instant) = @instant = instant
    end

    expect(builder.new(Time.find_zone('Europe/Paris').local(2026, 9, 14, 15, 3, 27.123)).timestamp)
      .to eq('2026-09-14T13:03:27.123Z')
  end
end
