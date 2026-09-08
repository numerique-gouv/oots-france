require 'webmock/cucumber'

# Nothing leaves the machine in the default profile, and what tries to leave
# fails the scenario, naming the address — the regime `spec/rails_helper.rb`
# applies. A
# scenario reaching a server of the Commission would otherwise depend on the
# network, and wait `DELAI_MAX_SERVICES_COMMUNS` on a host dropping packets.
Before('not @bout_en_bout') do
  WebMock.enable!
  WebMock.disable_net_connect!(allow_localhost: true)
end

# The end-to-end scenarios exist to cross the real central directories and the
# real gateway: WebMock is taken off their path entirely rather than told to let
# them through, so that nothing of it can stand between them and the network.
Before('@bout_en_bout') do
  WebMock.disable!
end
