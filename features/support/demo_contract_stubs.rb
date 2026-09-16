require Rails.root.join('spec/support/demo_contract_stubs')

# The scenarios of the demonstration give themselves the contract the procedure
# calls — the request and the state of the exchange. `spec/rails_helper.rb` does
# the same for RSpec, which does not load this directory.
#
# The demonstration calls itself over HTTP, so the contract is doubled at that
# boundary rather than at `Demo::EvidenceRequestClient`: what these scenarios
# are about is that the procedure goes through the contract at all.
World(DemoContractStubs)
