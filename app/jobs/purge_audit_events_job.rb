# Article 17(4) of the implementing regulation gives the log a term as well as a
# duty. Past whatever `DUREE_RETENTION_JOURNAL_MOIS` sets — twelve months being
# the floor the article imposes, not its value — what the log holds is personal
# data with no remaining reason to be kept, so deleting belongs to the
# obligation as much as writing does.
#
# `delete_all` and not `destroy_all`: there is no callback to run, and the
# records are read-only, which `destroy_all` would have to work around.
class PurgeAuditEventsJob < ApplicationJob
  queue_as :default

  def perform
    AuditEvent.where(occurred_at: ...Settings.audit_trail_retention.ago).delete_all
  end
end
