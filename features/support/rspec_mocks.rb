require 'rspec/mocks'

# What lets a scenario reach the halves of `spec/support/directory_stubs.rb`
# built on `allow` rather than on `stub_request` — the signature double, and it
# alone is what one scenario needs.
#
# A directory answer fabricated to make a case the captures do not hold — a
# member state declaring it issues nothing, which none publishes on the
# acceptance environment — no longer matches the signature that came with its
# capture, and that verification is what would fail first. So the answer that
# the console has a screen for cannot be served through the whole client any
# other way, and `spec/` already answers this exact problem this exact way.
#
# The lifecycle is opened for the tagged scenarios alone. Elsewhere `allow`
# raises rather than silently doing nothing, which is what keeps the scope
# honest: `@bout_en_bout` verifies every signature against the real directories,
# and that is the whole point there.
World(RSpec::Mocks::ExampleMethods)

Before('@javascript') { RSpec::Mocks.setup }

After('@javascript') do
  RSpec::Mocks.verify
ensure
  RSpec::Mocks.teardown
end
