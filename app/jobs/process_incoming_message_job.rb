# Handles one message the gateway told us about, in its own process: the
# gateway is entitled to a prompt acknowledgement of its notification.
#
# **No `retry_on`, deliberately.** The PMode carries `retention_downloaded="0"`,
# so `retrieveMessage` erased the message on the first attempt and a retry
# fails before it can even name the exchange it belonged to. Transient
# failures are absorbed one level down, by the retry policy of `DomibusClient`
# and `EvidenceForwarder`, which repeats a call without repeating the
# destructive read.
class ProcessIncomingMessageJob < ApplicationJob
  queue_as :default

  # The identifier alone: each step of the chain gives itself the
  # infrastructure it needs, so nothing here has to be kept in step with the
  # controller that starts the other direction.
  def perform(message_id)
    IncomingMessage::Process.call(message_id:)
  end
end
