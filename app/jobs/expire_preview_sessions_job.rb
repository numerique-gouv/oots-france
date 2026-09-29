# T2 and T3 of chapter 4.4 §4.4.3 for France's preview space. Nothing arrives
# to trigger them — a user who never comes back is exactly that — hence the
# sweep. The rows past T2 + T3 are destroyed last, once every expiry of this
# run has answered what it owed.
class ExpirePreviewSessionsJob < ApplicationJob
  queue_as :default

  def perform
    PreviewSession.past_redirection.or(PreviewSession.past_decision).find_each { |session| expire(session) }
    PreviewSession.past_retention.delete_all
  end

  private

  # One row may not carry away the others, as in `ExpireExchangesJob`.
  def expire(session)
    EvidenceProvision::ExpirePreview.call(preview_session: session)
  rescue StandardError => e
    Rails.logger.error(
      I18n.t('jobs.expire_preview_sessions_job.failed', id: session.id, error: "#{e.class}: #{e.message}"),
    )
  end
end
