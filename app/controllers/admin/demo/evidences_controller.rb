module Admin
  module Demo
    # The evidence itself, served to the one session that asked for it.
    #
    # Chapter 1 §4.2 governs both halves of this action: « Any evidences that are
    # returned in response are made available to the specific procedure end-user
    # that issued the query for those evidences » — hence the exchange read from
    # the session — and « The user can decide to not use the evidence but cannot
    # modify its content in any way » — hence the bytes as they arrived, under
    # the type they arrived with, never re-rendered.
    #
    # `inline`, so the browser opens it where it can and offers to save it
    # otherwise: the chapter has the user read the evidence and decide, which a
    # forced download makes a step longer than it is.
    class EvidencesController < Admin::BaseController
      include HoldsDemoIdentity
      include HoldsDemoExchange

      before_action :require_evidence

      def show
        send_data demo_request.evidence,
          type: Attachment::MIME_TYPE, disposition: :inline,
          filename: t('admin.demo.evidences.show.filename')
      end

      private

      def require_evidence
        redirect_to admin_demo_suivi_path unless demo_request.evidence?
      end
    end
  end
end
