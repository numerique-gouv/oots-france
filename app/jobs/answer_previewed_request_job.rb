# Answers a second request the preview space held, in a process of its own:
# the user's click is no place to wait on the gateway.
class AnswerPreviewedRequestJob < ApplicationJob
  queue_as :default

  def perform(preview_session_id)
    EvidenceProvision::AnswerAfterPreview.call(preview_session_id:)
  end
end
