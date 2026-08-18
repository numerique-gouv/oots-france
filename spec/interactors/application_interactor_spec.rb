require 'rails_helper'

RSpec.describe ApplicationInteractor do
  # Barely any of what `FAILURES` lists reaches a rendered page; nothing else
  # would notice one shipped without its wording.
  it 'says every failure it declares' do
    expect_said(described_class::FAILURES.map { |key| "interactors.failures.#{key}" })
  end

  it 'declares every failure the interactors raise' do
    raised = Dir['app/interactors/**/*.rb']
      .flat_map { |path| File.read(path).scan(/fail_with_error\(:(\w+)/) }
      .flatten.map(&:to_sym).uniq

    expect(described_class::FAILURES).to include(*raised)
  end
end
