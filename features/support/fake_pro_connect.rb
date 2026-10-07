require_relative 'fake_pro_connect/identities'
require_relative 'fake_pro_connect/runner'
require_relative 'fake_pro_connect/server'

# ProConnect, as the administration space meets it: the fake `make up` starts
# beside the application and the end-to-end suite signs in through, so that
# neither a development machine nor the continuous integration needs a
# declaration on ProConnect's partner space. `docs/test_e2e.md` describes it.
#
# **Nothing under `fake_pro_connect/` may use ActiveSupport**: the server runs
# as a process of its own, without Rails.
module FakeProConnect
  class << self
    # The instance the suite started, when nothing already answered.
    attr_accessor :running
  end
end
