require 'rails_helper'

RSpec.describe SlotReading do
  # `require_content` names what is missing with a key rather than a sentence,
  # so nothing static ties the parsers to their wordings: `i18n-tasks` reads
  # neither side of a key it never sees written as a lookup.
  it 'says every key its parsers write' do
    written = Dir['app/parsers/**/*.rb']
      .flat_map { |path| File.read(path).scan(/'(parsers(?:\.[a-z_]+)+)'/) }
      .flatten.uniq

    expect_said(written)
  end
end
