require Rails.root.join('spec/support/fixtures')
require Rails.root.join('spec/support/directory_stubs')

# The demonstration scenarios give themselves the Evidence Broker answer the
# home page reads. `spec/rails_helper.rb` does the same for RSpec, which does
# not load this directory.
#
# The halves resting on `stub_request` are reachable as they stand. The two
# built on `allow` need rspec-mocks, which `features/support/rspec_mocks.rb`
# opens for the scenarios tagged `@javascript` and for those alone: the
# signature double is what one of them needs, and no other scenario doubles a
# Ruby object.
#
# The resolution, though, is settled by configuration for every scenario of the
# default profile — and for that profile alone: `features/support/env.rb`
# refuses the base URL outright under `@bout_en_bout`, where the discovery is
# the point, and the deployment's own environment carries the trust store
# there.
#
# The base URL short-circuits the NAPTR lookup. The trust store is the
# acceptance one because the fixtures are captures of that environment,
# signature headers included: the verification runs for real against them, and
# a runner that carries no `.env.oots` — the unit workflow's — would otherwise
# have nothing to verify with.
World(Fixtures, DirectoryStubs)

Before('not @bout_en_bout') do
  ENV['URL_BASE_EVIDENCE_BROKER'] ||= "#{DirectoryStubs::ACCEPTANCE}/eb/"
  # `presence` and not `||=`: a variable declared empty is what `Settings`
  # refuses, and an empty string is not `nil`.
  ENV['CERTIFICATS_SERVICES_COMMUNS'] =
    ENV['CERTIFICATS_SERVICES_COMMUNS'].presence || 'config/certificats/services_communs_acc.pem'
end
