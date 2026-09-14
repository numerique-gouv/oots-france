require Rails.root.join('spec/support/fixtures')
require Rails.root.join('spec/support/directory_stubs')

# The demonstration scenarios give themselves the Evidence Broker answer the
# home page reads. `spec/rails_helper.rb` does the same for RSpec, which does
# not load this directory.
#
# Only the halves resting on `stub_request` are reachable here: the two that
# double `CommonServicesInstance` and the signature are built on `allow`, which
# only rspec-mocks provides. The address is therefore settled by configuration
# instead — a base URL short-circuits the NAPTR lookup — and it is posted for
# the default profile alone, `features/support/env.rb` refusing it outright
# under `@bout_en_bout`, where the discovery is the point.
World(Fixtures, DirectoryStubs)

Before('not @bout_en_bout') do
  ENV['URL_BASE_EVIDENCE_BROKER'] ||= "#{DirectoryStubs::ACCEPTANCE}/eb/"
end
