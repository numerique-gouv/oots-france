require_relative 'fake_france_connect/authentication'
require_relative 'fake_france_connect/authorize_request'
require_relative 'fake_france_connect/clients'
require_relative 'fake_france_connect/delivery'
require_relative 'fake_france_connect/identities'
require_relative 'fake_france_connect/pages'
require_relative 'fake_france_connect/responses'
require_relative 'fake_france_connect/runner'
require_relative 'fake_france_connect/server'
require_relative 'fake_france_connect/store'
require_relative 'fake_france_connect/tokens'

# The fourth role the end-to-end suite plays, beside the calling requester and
# the foreign correspondent: FranceConnect+ and, behind it, the eIDAS bridge
# and a member state's node.
#
# The demonstration procedure has no other way to hold a European user's
# identity — the FranceConnect+ sandbox wants a reachable deployment, which
# continuous integration cannot give it. What the fake answers, refuses,
# verifies and chains comes from the FranceConnect sources read at 93cd5d7; no
# line of them is copied here, and nothing of them is built.
#
# `docs/test_e2e.md` describes the role, its identities, and where the fake
# knowingly departs from the sources.
#
# **Nothing under `fake_france_connect/` may use ActiveSupport**: the server
# runs as a process of its own, without Rails, so that the local stack can run
# it as a service (OOTS-192). `blank?`, `present?` and `pluck` are not
# available there, and RuboCop's `Rails/*` cops will happily suggest them.
module FakeFranceConnect
  class << self
    # The single instance the suite starts, so that a scenario can drive it
    # without a step having mounted it — which is what RG14 asks of a role.
    attr_accessor :running
  end
end
