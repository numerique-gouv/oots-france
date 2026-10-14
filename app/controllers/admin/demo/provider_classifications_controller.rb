module Admin
  module Demo
    # The answers one card of the documents page gives to the questions the Data
    # Service Directory asks before it can name the provider — `DSD:ERR:0005`,
    # chapter 3.1.4 §4.4.3.3: « For each EvidenceProviderClassification of the
    # DSD:ERR:0005 a separate answer must be provided by the user and included
    # to the second query ». Answering asks only the directories, and opens
    # nothing: the request leaves on the button.
    #
    # Answered with the card alone, resolved on those answers, of which
    # `demo_card_controller.js` splices only what the resolution says — the
    # questions keep the focus and the values typed, the discipline of
    # `CountriesController` (RGAA 7.4). The card's row of `Demo::Card` is
    # written again, so that a reload renders the card on its answers, and what
    # the card now names is what its button will send.
    class ProviderClassificationsController < Admin::BaseController
      include HoldsDemoNames
      include BuildsDemoCards

      # An outage carries no code, and the card says it in one sentence for
      # every cause, which the browser shows on any `5xx` that is not a fragment.
      rescue_from CommonServicesError, with: :report_unreachable_directories

      # A card following a request was sent on its answers and asks nothing. An
      # answer missing, or one to a question the directory does not ask, comes
      # from no form this application rendered — or from one rendered before
      # the directory changed — and the page is reloaded on it.
      def update
        return head :unprocessable_content unless offered?

        wording = resolved_card

        return head :unprocessable_content unless answers?(wording)

        remember_demo_name(wording)
        answer_with_card(wording)
      end

      private

      def resolved_card
        DemoResolutionWording.new(resolve_card(requirement_uuid, card_country(requirement_uuid),
          card_evidence_type(requirement_uuid), answers))
      end

      def offered?
        requirement_uuid.match?(SemanticRepositoryAsset::UUID) && !held_card?(requirement_uuid) && answers.any?
      end

      def answers?(wording)
        wording.requirement_uuid == requirement_uuid && wording.asking? && answers.size == wording.questions.size &&
          EvidenceProviderClassification.all_answered?(wording.questions, answers)
      end

      def report_unreachable_directories(error)
        Rails.logger.warn(I18n.t('controllers.admin.demo.provider_classifications.unreachable', error: error.message))

        head :bad_gateway
      end

      def answers
        @answers ||= params.permit(classificationFournisseur: {})[:classificationFournisseur].to_h
      end

      def requirement_uuid = params[:exigence].to_s
    end
  end
end
