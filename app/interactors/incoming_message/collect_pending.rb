module IncomingMessage
  # Asks the gateway what it is still holding, and files a job per message.
  #
  # A step and not a job body: the gateway defaults on the context, the way
  # every other step gives itself its infrastructure, so a spec overrides by
  # keyword instead of the job carrying a parameter the scheduler never passes.
  class CollectPending < ApplicationInteractor
    def call
      gateway.pending_messages.message_ids.each do |message_id|
        ProcessIncomingMessageJob.perform_later(message_id)
      end
    end
  end
end
