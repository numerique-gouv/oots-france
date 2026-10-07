module Admin
  module Demo
    # The page an exchange is asked for from: it carries the identity the
    # authentication attested — shown and never typed, chapter 2.2 §2 making the
    # portal answerable for the identity in the request matching the one the eID
    # means yielded — and names the evidence provider and the evidence type,
    # which requirement 27 of chapter 1 §2 asks for word for word — « The user is
    # provided with information about name of evidence provider and evidence type
    # for confirmation, before any request is made. » Unable to name them, it
    # offers nothing to confirm: the requirement is a condition of the request,
    # not a decoration on it.
    #
    # The button itself, and what becomes of a click on it, belong to
    # `RequestsController`. This page renders one zone per requirement it can
    # name, each in whatever state the register of its journey puts it:
    # chapter 4.4 §4.2.2 has
    # « different basic flows … executed sequentially and/or in parallel », so
    # no card waits on its neighbour.
    class DocumentsController < Admin::BaseController
      include ReadsDemoRequest
      include HoldsDemoNames
      include BuildsDemoCards

      # A directory that refuses says so with a code and stays on the page; one
      # that cannot be reached carries none, and `DirectoryLookup::Refusing`
      # re-raises it. Rescued here for the same reason the console's directory
      # pages rescue it: the operator reads what happened rather than a 500.
      rescue_from CommonServicesError, with: :report_unreachable_directories

      helper_method :requirement_card

      before_action :record_return, only: :show

      # The identity is the one thing on this page no directory has to answer
      # for, and the rescue below renders the same template.
      #
      # The chain `DirectoryLookup::ResolveAll` walks is the one the console
      # already replays on `/admin/common_services/resolution`, and the one a
      # request walks before sending anything. Replayed here for the screen
      # alone: the TDD normalise what the portal shows, never how it learns it,
      # and the request itself goes out through the contract.
      #
      # Each card is resolved in its own member state, the one the user chose on
      # it or the one its request went to — `HoldsDemoCountries` says which.
      #
      # The cards the operator added follow those of the procedure, each
      # resolved from its own requirement, and the page then offers to add any
      # other the catalogue holds.
      def show
        resolved = DirectoryLookup::ResolveAll.call(procedure_code: code,
          country_code: Settings.common_services_country_code, countries: card_countries)
        @procedure = procedure_wording(resolved.requirements)
        @requirements = resolved.resolutions.map { |lookup| DemoResolutionWording.new(lookup) }
        @added = resolved_added_cards(@requirements.map(&:requirement_uuid))

        cards = @requirements + @added

        remember_demo_names(@procedure, cards)
        @addable = addable_requirements(cards.map(&:requirement_uuid))
      end

      private

      # The user back from the preview space, by the return address France
      # redirects to with the two identifiers of the exchange. Chapter 4.9 §5:
      # « Confirm that the user accessing the Online Procedure Portal using the
      # return URL is the user that is executing the associated procedure ».
      # The zone of that card then waits for the outcome again, « from the state
      # it was in before the use of OOTS ».
      def record_return
        ::Demo::Request.return_from_preview!(journey:, exchange_id: params[:echange].to_s,
          conversation_id: params[:conversation].to_s)
      end

      # The heading the home page stands under, said again here: the two are one
      # journey, and the procedure is what it is about. Built on the requirements
      # the resolution has already read — its first step asks the very question
      # the home page asks — so the page learns it without a query of its own.
      def procedure_wording(requirements)
        DemoProcedureWording.new(
          code:, requirements:, published_name: code_lists.procedure_names(lang: :en)[code],
          published_name_language: 'en',
        )
      end

      def code = journey.procedure_code

      def resolved_added_cards(listed)
        added_cards.values.reject { |card| card.requirement_uuid.in?(listed) }.map do |card|
          DemoResolutionWording.new(resolve_added_card(card, card_country(card.requirement_uuid)))
        end
      end

      # Every requirement of the Evidence Broker's catalogue — its first query,
      # asked with neither of its optional parameters (chapter 3.2.4 §4.2) — less
      # those the page already carries a card for, named as the directory names
      # them. A catalogue that cannot be read costs this choice and nothing
      # else: the cards stand, and the log keeps why.
      def addable_requirements(carried)
        Directories::Catalogue.new.requirements
          .reject { |requirement| requirement.uuid.in?(carried) }.map { |requirement| addable_option(requirement) }
      rescue CommonServicesError => e
        Rails.logger.warn(I18n.t('controllers.admin.demo.catalogue_unreachable', error: e.message))

        nil
      end

      # In English first, like the cards: the page is the portal.
      def addable_option(requirement)
        languages = DemoResolutionWording::LANGUAGES

        [requirement.label(languages:) || requirement.uuid, requirement.uuid,
         { lang: requirement.label_language(languages:) }]
      end

      def report_unreachable_directories(error)
        @unreachable = error.message
        @procedure = procedure_wording(nil)
        @requirements = []
        @added = []

        render :show, status: :bad_gateway
      end
    end
  end
end
