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
      # A directory that cannot be reached costs the page its list of
      # requirements and nothing else: the one thing this page is for is the way
      # in, and that way needs no directory.
      rescue_from CommonServicesError, with: :stand_without_the_directories

      # The title in English, where the rest of the console reads the French
      # column: this page is the portal and not the console, and its reader is a
      # user of another Member State — the same reason the sign-in button
      # carries the label FranceConnect+ gives its European flow.
      def show
        code = ::Demo::RequestEvidence::PROCEDURE_CODE
        @procedure_name = CodeListClient.new.procedure_names(lang: :en)[code]
        @heading = ProcedureComponent.label(code, @procedure_name, limit: nil)
        @requirements = DemoRequirements.new(requirements)
      end

      private

      # The first step of the chain a request walks, and it alone: what France,
      # as the requester's jurisdiction, must see satisfied for this procedure.
      # The two that follow — which evidence types satisfy a requirement, who
      # holds them — belong to the confirmation page, which names the provider
      # and the type requirement 27 of chapter 1 §2 asks for.
      def requirements
        DirectoryLookup::FetchRequirements.call(
          evidence_broker: EvidenceBrokerClient.new,
          procedure_code: ::Demo::RequestEvidence::PROCEDURE_CODE,
        ).requirements
      end

      def stand_without_the_directories(error)
        Rails.logger.warn(I18n.t('controllers.admin.demo.home.no_requirements', error: error.message))

        @requirements = DemoRequirements.new(nil)

        render :show
      end
    end
  end
end
