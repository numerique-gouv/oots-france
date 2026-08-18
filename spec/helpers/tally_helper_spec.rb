require 'rails_helper'

RSpec.describe TallyHelper do
  # `tally_forms` composes `.zero`, `.one` and `.other` from a key it receives:
  # the three leaves are never written as a lookup, so nothing static sees them.
  it 'says every plural form the browser is handed' do
    counted = Dir['app/views/**/*.erb']
      .flat_map { |path| File.read(path).scan(/tally_forms\('([\w.]+)'\)/) }
      .flatten.uniq

    expect_said(counted.product(%w[zero one other]).map { |key, form| "#{key}.#{form}" })
  end
end
