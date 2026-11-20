module Admin
  module Demo
    # The evidence itself, served to the one session that asked for it.
    #
    # Chapter 1 §4.2 governs both halves of this action: « Any evidences that are
    # returned in response are made available to the specific procedure end-user
    # that issued the query for those evidences » — hence the request looked up
    # under the journey the session holds, never named by the incoming one — and
    # « The user can decide to not use the evidence but cannot modify its content
    # in any way » — hence the bytes as they arrived, under the type they arrived
    # with, never re-rendered.
    #
    # `inline` where the evidence may open in place, so the browser opens it:
    # the chapter has the user read the evidence and decide, which a forced
    # download makes a step longer than it is. `Demo::Request` says which
    # evidence may.
    #
    # `exigence` and `type` say which of this journey's own requests is meant,
    # the page offering one document per evidence type it asked for. They name a
    # block of a zone, never an exchange: what may be served is still what this
    # journey asked for.
    class EvidencesController < Admin::BaseController
      include ReadsDemoRequest

      before_action :require_evidence

      def show
        send_data demo_request.evidence,
          type: demo_request.evidence_mime_type,
          disposition: demo_request.evidence_opens_in_place? ? :inline : :attachment,
          filename: t('admin.demo.evidences.show.filename', extension: demo_request.evidence_extension)
      end

      private

      # Back to the page the document is offered from: an address reached
      # without one is a journey that has yet to get that far, not an error.
      def require_evidence
        redirect_to admin_demo_documents_path unless demo_request&.evidence?
      end

      def demo_request = demo_request_for(params[:exigence].to_s, params[:type].to_s)
    end
  end
end
