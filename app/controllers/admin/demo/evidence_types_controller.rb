module Admin
  module Demo
    # The evidence type one card of the documents page names, where its country
    # publishes several for the requirement and the user picks one there —
    # requirement 26 of chapter 1 §2: « Evidence requesters shall give users the
    # possibility to select and request the types of evidence. » Choosing asks
    # only the directories, and opens nothing: the request leaves on the button.
    #
    # Answered with the card alone, resolved on that type in the card's country,
    # which `demo_card_controller.js` splices into the page under the list the
    # user is still on — the discipline of `CountriesController`, for the same
    # reason (RGAA 7.4). The card's row of `Demo::Card` is written again, so that
    # a reload renders the card on the type chosen, and what the card now names
    # is what its button will send.
    class EvidenceTypesController < Admin::BaseController
      include HoldsDemoNames
      include BuildsDemoCards

      # An outage carries no code, and the card says it in one sentence for
      # every cause, which the browser shows on any `5xx` that is not a fragment.
      rescue_from CommonServicesError, with: :report_unreachable_directories

      # A card following a request stays on the type of that request, whatever
      # is submitted meanwhile. A type the country does not publish for the
      # requirement comes from no list this application rendered — or from one
      # rendered before the directory changed — and the page is reloaded on it.
      def update
        return head :unprocessable_content unless offered?

        wording = resolved_card

        return head :unprocessable_content unless answers?(wording)

        remember_demo_name(wording) unless held_card?(requirement_uuid)
        answer_with_card(wording)
      end

      private

      # In the country the card stands in, which `card_country` reads whether
      # or not a request holds it.
      def resolved_card
        DemoResolutionWording.new(resolve_card(requirement_uuid, card_country(requirement_uuid),
          held_evidence_type(requirement_uuid) || evidence_type))
      end

      def offered? = [requirement_uuid, evidence_type].all? { |uuid| uuid.match?(SemanticRepositoryAsset::UUID) }

      def answers?(wording)
        wording.requirement_uuid == requirement_uuid && (held_card?(requirement_uuid) || wording.evidence_type_uuid == evidence_type)
      end

      def report_unreachable_directories(error)
        Rails.logger.warn(I18n.t('controllers.admin.demo.evidence_types.unreachable', error: error.message))

        head :bad_gateway
      end

      def evidence_type = params[:type].to_s

      def requirement_uuid = params[:exigence].to_s
    end
  end
end
