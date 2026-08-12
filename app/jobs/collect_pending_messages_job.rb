# Sweeps whatever the gateway is still holding.
#
# Not a safety net against a lost notification — the push rule already retries
# five times over an hour (`wsplugin.push.rules.oots.retry`). What it catches is
# the window *after* those retries are spent: the gateway then stops trying, and
# since `markAsDownloaded` is false the message is still sitting there,
# retrievable, for the two and a half days `retention_undownloaded` allows.
# Without this sweep nothing would ever go and get it.
#
# Idempotent by construction: the PMode erases a message once downloaded, so a
# message collected twice is simply not there the second time.
class CollectPendingMessagesJob < ApplicationJob
  queue_as :default

  # The scheduler passes nothing, so the default is the only path in production
  # and stays serialisable. The keyword exists for the spec.
  def perform(gateway: DomibusClient.new)
    gateway.pending_messages.message_ids.each do |message_id|
      ProcessIncomingMessageJob.perform_later(message_id)
    end
  end
end
