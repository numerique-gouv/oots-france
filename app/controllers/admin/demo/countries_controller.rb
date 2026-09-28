module Admin
  module Demo
    # The member state one card of the documents page resolves its requirement
    # in, as the user picks it there. Choosing asks only the directories:
    # chapter 1 §10.1 has the country settled at step 21 and the request sent at
    # step 25, so nothing is opened here.
    #
    # Answered with the card alone, resolved in that country, which
    # `demo_country_controller.js` splices into the page around the list the
    # user is still on: a content update and not a change of context, which a
    # choice in a list must not cause by itself (RGAA 7.4). The choice is kept
    # in the session all the same, so that a reload renders the card where it
    # was left, and what the card now names is what its button will send.
    class CountriesController < Admin::BaseController
      include HoldsDemoNames
      include BuildsDemoCards

      UUID = /\A\h{8}-\h{4}-\h{4}-\h{4}-\h{12}\z/

      # An outage carries no code, and the page that shows it is the documents
      # page: the browser reloads it on any answer that is not a fragment. Logged
      # all the same, the reload finding the directories answering again
      # otherwise leaving no trace of what failed.
      rescue_from CommonServicesError, with: :report_unreachable_directories

      # A code the list does not offer comes from no page this application
      # renders, and is refused before any directory is asked what it makes of
      # it — which no chapter settles. A card following a request stays in the
      # country of that request, whatever is submitted meanwhile.
      def update
        return head :unprocessable_content unless offered?

        held = held_country(requirement_uuid)
        wording = DemoResolutionWording.new(resolve(held || country))

        return head :unprocessable_content unless wording.requirement_uuid == requirement_uuid

        remember_choice(wording) unless held

        response.set_header('Deferred-Fragment', '1')
        render requirement_card(wording), layout: false
      end

      private

      def resolve(country_code)
        DirectoryLookup::Resolve.call(
          evidence_broker: EvidenceBrokerClient.new, data_service_directory: DataServiceDirectoryClient.new,
          procedure_code: ::Demo::RequestEvidence::PROCEDURE_CODE, country_code:, requirement_id: requirement_uuid,
        )
      end

      def offered? = offered_country?(country) && requirement_uuid.match?(UUID)

      def remember_choice(wording)
        choose_country(requirement_uuid, country)
        remember_demo_name(wording)
      end

      def report_unreachable_directories(error)
        Rails.logger.warn(I18n.t('controllers.admin.demo.countries.unreachable', error: error.message))

        head :bad_gateway
      end

      def country = params[:pays].to_s

      def requirement_uuid = params[:exigence].to_s
    end
  end
end
