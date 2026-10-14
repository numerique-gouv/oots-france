module Admin
  module Demo
    # The member state one card of the documents page resolves its requirement
    # in, as the user picks it there. Choosing asks only the directories:
    # chapter 1 §10.1 has the country settled at step 21 and the request sent at
    # step 25, so nothing is opened here.
    #
    # Answered with the card alone, resolved in that country, which
    # `demo_card_controller.js` splices into the page around the list the
    # user is still on: a content update and not a change of context, which a
    # choice in a list must not cause by itself (RGAA 7.4). The card's row of
    # `Demo::Card` is written again, so that a reload renders the card where it
    # was left, and what the card now names is what its button will send.
    #
    # The evidence types are the country's, so choosing another undoes the type
    # chosen: the card is resolved in its new country on none, and offers the
    # choice again where that country publishes several. The answers to the
    # questions of the Data Service Directory go with the type.
    class CountriesController < Admin::BaseController
      include HoldsDemoNames
      include BuildsDemoCards

      # An outage carries no code, and what the card says of it is one sentence
      # for every cause, which the browser shows on any `5xx` that is not a
      # fragment. Logged, so that the application log keeps what the card does
      # not say.
      rescue_from CommonServicesError, with: :report_unreachable_directories

      # A code the list does not offer comes from no page this application
      # renders, and is refused before any directory is asked what it makes of
      # it — which no chapter settles. A card following a request stays in the
      # country of that request, whatever is submitted meanwhile.
      def update
        return head :unprocessable_content unless offered?

        wording = resolved_card

        return head :unprocessable_content unless wording.requirement_uuid == requirement_uuid

        remember_demo_name(wording) unless held_card?(requirement_uuid)
        answer_with_card(wording)
      end

      private

      def resolved_card
        DemoResolutionWording.new(
          resolve_card(requirement_uuid, held_country(requirement_uuid) || country, held_evidence_type(requirement_uuid),
            held_provider_classifications(requirement_uuid).to_h),
        )
      end

      def offered? = offered_country?(country) && requirement_uuid.match?(SemanticRepositoryAsset::UUID)

      def report_unreachable_directories(error)
        Rails.logger.warn(I18n.t('controllers.admin.demo.countries.unreachable', error: error.message))

        head :bad_gateway
      end

      def country = params[:pays].to_s

      def requirement_uuid = params[:exigence].to_s
    end
  end
end
