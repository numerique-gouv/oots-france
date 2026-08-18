require 'rails_helper'

RSpec.describe StrictValidation do
  # The subject travels as a symbol, so nothing static ties the call sites to
  # the wordings: `i18n-tasks` reads neither side of a key it never sees
  # written as a lookup.
  it 'says every subject it declares' do
    expect_said(described_class::SUBJECTS.map { |subject| "models.strict_validation.subjects.#{subject}" })
  end

  it 'declares every subject the application reproaches' do
    reproached = Dir['app/**/*.rb']
      .flat_map { |path| File.read(path).scan(/\.validate!\(:(\w+)/) }
      .flatten.map(&:to_sym).uniq

    expect(described_class::SUBJECTS).to include(*reproached)
  end
end
