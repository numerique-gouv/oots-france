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

  def perform(message_id)
    IncomingMessage::Process.call(
      message_id:,
      gateway: DomibusClient.new,
      evidence_forwarder: EvidenceForwarder.new,
      requesters: Directories::EvidenceRequesters.new,
      uuid: UuidGenerator.new,
      audit_trail: AuditTrail.new,
    )
  end
end
