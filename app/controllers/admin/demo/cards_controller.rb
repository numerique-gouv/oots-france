module Admin
  module Demo
    # A card the operator adds to the documents page, beyond those the Evidence
    # Broker lists for the procedure of the journey, and takes off it again.
    #
    # Adding writes a row of `Demo::Card` under the journey, carrying the
    # requirement the catalogue names, and nothing else: the page resolves the
    # card from it, and asks for nothing until its button is clicked. Taking it
    # off deletes that row and nothing else — a request it opened goes on, in
    # `demo_requests` and in the exchange log, and a card of the same
    # requirement added again stands in the country of that request.
    #
    # `::Demo::` and not `Demo::`: this file lives in `Admin::Demo`, which would
    # otherwise answer for the name.
    class CardsController < Admin::BaseController
      include HoldsDemoJourney

      # The form was rendered while the catalogue answered, and the click may
      # land after it stopped: back to the page, which then offers no choice to
      # add, the log keeping why.
      rescue_from CommonServicesError, with: :report_unreachable_catalogue

      # A submission that chose nothing adds nothing, and the page comes back as
      # it was; one resubmitted lands on the card it already added. A value that
      # is no UUID comes from no form this application renders.
      def create
        return redirect_to(admin_demo_documents_path) if requirement_uuid.blank?
        return head :unprocessable_content unless requirement_uuid.match?(SemanticRepositoryAsset::UUID)
        return back_to_the_card if carried?

        add(Directories::Catalogue.new.requirement(requirement_uuid))
      rescue ActiveRecord::RecordNotUnique
        back_to_the_card
      end

      # Only a card the operator added: those the Evidence Broker lists for the
      # procedure are what the page shows it for.
      def destroy
        ::Demo::Card.added(journey.id).where(requirement_uuid:).delete_all

        redirect_to admin_demo_documents_path
      end

      private

      def requirement_uuid = params[:exigence].to_s

      # Read in the catalogue the page offered it from, so that the row names
      # the requirement as the Evidence Broker does. One the catalogue no
      # longer holds — it changed since the page was rendered — adds nothing,
      # and the log says why.
      def add(requirement)
        if requirement.nil?
          Rails.logger.warn(I18n.t('controllers.admin.demo.cards.uncatalogued', requirement: requirement_uuid))

          return redirect_to(admin_demo_documents_path)
        end

        ::Demo::Card.add(journey_id: journey.id, requirement:, country_code: card_country,
          languages: DemoResolutionWording::LANGUAGES)
        back_to_the_card
      end

      def carried? = ::Demo::Card.exists?(journey_id: journey.id, requirement_uuid:)

      # Where the last request of the requirement went, whatever became of it;
      # the deployment's own country otherwise.
      def card_country
        ::Demo::Request.last_country(journey_id: journey.id, requirement_uuid:) || Settings.common_services_country_code
      end

      def report_unreachable_catalogue(error)
        Rails.logger.warn(I18n.t('controllers.admin.demo.catalogue_unreachable', error: error.message))

        redirect_to admin_demo_documents_path
      end

      def back_to_the_card = redirect_to(admin_demo_documents_path(anchor: "exigence-#{requirement_uuid}"))
    end
  end
end
