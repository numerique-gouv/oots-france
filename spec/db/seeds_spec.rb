require 'rails_helper'

# The demonstration set names constants — procedure codes, conversation statuses
# — from inside a block `Rails.env.development?` guards, so nothing else in this
# suite ever evaluates it: a constant renamed everywhere but here stays green
# through RSpec and fails the end-to-end workflow, the only one that runs
# `db:seed`. This example is what makes that a second rather than four minutes.
RSpec.describe 'db/seeds.rb' do
  it 'replays without raising' do
    expect { replay }.not_to raise_error
  end

  it 'opens one exchange per status the console can show' do
    replay

    expect(Exchange.distinct.pluck(:status)).to match_array(Exchange::STATUSES)
  end

  # The seed narrates what it wrote, which the suite has no use for.
  def replay
    allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('development'))
    spoken = $stdout
    $stdout = StringIO.new

    load Rails.root.join('db/seeds.rb')
  ensure
    $stdout = spoken
  end
end
