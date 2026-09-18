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
# It is also what lets a scenario say which FranceConnect+ this deployment
# declares, rather than depending on what the `.env.oots` of the machine
# carries: `Settings` is the one reader of that, and forcing it is how the
# scenario states it.
#
# Everywhere but `@bout_en_bout`, where `allow` raises rather than silently
# doing nothing — and that is what keeps the scope honest: those scenarios
# verify every signature against the real directories and walk the real
# configuration, which is the whole point there.
World(RSpec::Mocks::ExampleMethods)

Before('not @bout_en_bout') { RSpec::Mocks.setup }

After('not @bout_en_bout') do
  RSpec::Mocks.verify
ensure
  RSpec::Mocks.teardown
end
