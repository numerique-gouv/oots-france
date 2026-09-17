# Article 17(4) of the implementing regulation gives the log a term as well as a
# duty, and deleting belongs to the obligation as much as writing does. Which
# lines are past that term is `AuditEvent.past_retention`'s to say.
#
# `delete_all` and not `destroy_all`: there is no callback to run, and the
# records are read-only, which `destroy_all` would have to work around.
class PurgeAuditEventsJob < ApplicationJob
  queue_as :default

  def perform = AuditEvent.past_retention.delete_all
end
