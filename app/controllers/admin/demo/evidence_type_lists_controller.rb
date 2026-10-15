module Admin
  module Demo
    # The combination of evidence types one card of the documents page names,
    # where its country publishes several for the requirement and the user picks
    # one there — chapter 3.2.2 §2.3: « The user can select an 'Evidence Type
    # List' amongst the ones proposed by the Evidence Broker ». Choosing asks
    # only the directories, and opens nothing: the requests leave on the button.
    #
    # Answered with the card alone, resolved on that combination in the card's
    # country, which `demo_card_controller.js` splices into the page under the
    # list the user is still on — the discipline of `CountriesController`, for
    # the same reason (RGAA 7.4). The card's row of `Demo::Card` is written
    # again, so that a reload renders the card on the combination chosen, and
    # what the card now names is what its button will send. The answers given on
    # each line of the combination left are undone, even on a type the new one
    # carries too: the card is resolved on none.
    class EvidenceTypeListsController < Admin::BaseController
      include HoldsDemoNames
      include BuildsDemoCards

      # An outage carries no code, and the card says it in one sentence for
      # every cause, which the browser shows on any `5xx` that is not a fragment.
      rescue_from CommonServicesError, with: :report_unreachable_directories

      # A card following a request stays on the combination of that request,
      # whatever is submitted meanwhile. A combination the country does not
      # publish for the requirement comes from no list this application
      # rendered — or from one rendered before the directory changed — and the
      # page is reloaded on it.
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
        DemoCardWording.new(resolve_card(requirement_uuid, card_country(requirement_uuid),
          held_evidence_type_list(requirement_uuid) || combination, held_provider_classifications(requirement_uuid)))
      end

      # The `sdg:Identifier` of the list, whose form chapter 3.2.4 §4.3.2 leaves
      # to the member state, so none is checked here; `answers?` checks that the
      # country publishes it.
      def offered? = requirement_uuid.match?(SemanticRepositoryAsset::UUID) && combination.present?

      def answers?(wording)
        wording.requirement_uuid == requirement_uuid && (held_card?(requirement_uuid) || wording.combination_id == combination)
      end

      def report_unreachable_directories(error)
        Rails.logger.warn(I18n.t('controllers.admin.demo.evidence_type_lists.unreachable', error: error.message))

        head :bad_gateway
      end

      def combination = params[:combinaison].to_s

      def requirement_uuid = params[:exigence].to_s
    end
  end
end
