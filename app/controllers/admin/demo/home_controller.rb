module Admin
  module Demo
    # The front half of an Online Procedure Portal, which this repository
    # otherwise only implements the back half of: the operator plays the user of
    # a French procedure asking for a piece of evidence. The foreign one is the
    # user, not the evidence — `docs/eidas_context.md` says why the demonstration
    # keeps requester and provider both French.
    #
    # Nothing here touches an exchange.
    class HomeController < Admin::BaseController
      # A directory that cannot be reached costs the page the title France
      # declared and the list of requirements, and nothing else: the one thing
      # this page is for is the way in, and that way needs no directory.
      rescue_from CommonServicesError, with: :stand_without_the_directories

      def show
        @wording = wording(requirements)
      end

      private

      def code = ::Demo::RequestEvidence::PROCEDURE_CODE

      # The first of the Evidence Broker's two queries (chapter 3.2.4), and it
      # alone: what France, as the requester's jurisdiction, must see satisfied
      # for this procedure, carrying with it the titles France declared the
      # procedure under. The two steps that follow — which evidence types
      # satisfy a requirement, who holds them — belong to the confirmation page,
      # which names the provider and the type requirement 27 of chapter 1 §2
      # asks for.
      def requirements
        DirectoryLookup::FetchRequirements.call(
          evidence_broker: EvidenceBrokerClient.new, procedure_code: code,
        ).requirements
      end

      # The SDG title, read in English where the rest of the console reads the
      # French column: this page is the portal and not the console, and its
      # reader is a user of another Member State — the same reason the sign-in
      # button carries the label FranceConnect+ gives its European flow. The
      # language travels with the name, the wording having no way to guess which
      # column was read.
      def wording(requirements)
        DemoProcedureWording.new(
          code:, requirements:, published_name: CodeListClient.new.procedure_names(lang: :en)[code],
          published_name_language: 'en',
        )
      end

      def stand_without_the_directories(error)
        Rails.logger.warn(I18n.t('controllers.admin.demo.home.no_requirements', error: error.message))

        @wording = wording(nil)

        render :show
      end
    end
  end
end
