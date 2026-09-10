# The requester contract unreachable, as the demonstration procedure sees it.
#
# Faraday raises where the network fails, and that exception stops at
# `app/clients/`: a controller rescuing it would be the one place in this
# deployment where the presentation layer names the HTTP library. The procedure
# is a client of a published contract, so what reaches it is what any French
# service provider's server would see — an address that did not answer.
#
# Distinct from a contract that answered something unusable, which is not an
# outage and reads on `Demo::ContractAnswer`.
class DemoContractError < StandardError; end
