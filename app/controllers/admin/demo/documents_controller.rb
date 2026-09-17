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
    # name, each in whatever state the session it is reloaded from puts it:
    # chapter 4.4 §4.2.2 has
    # « different basic flows … executed sequentially and/or in parallel », so
    # no card waits on its neighbour.
    class DocumentsController < Admin::BaseController
      include ReadsDemoRequest
      include HoldsDemoNames

      # A directory that refuses says so with a code and stays on the page; one
      # that cannot be reached carries none, and `DirectoryLookup::Refusing`
      # re-raises it. Rescued here for the same reason the console's directory
      # pages rescue it: the operator reads what happened rather than a 500.
      rescue_from CommonServicesError, with: :report_unreachable_directories

      helper_method :provider_country_code, :provider_country_name, :demo_request_zone

      # The identity is the one thing on this page no directory has to answer
      # for, and the rescue below renders the same template.
      #
      # The chain `DirectoryLookup::ResolveAll` walks is the one the console
      # already replays on `/admin/common_services/resolution`, and the one a
      # request walks before sending anything. Replayed here for the screen
      # alone: the TDD normalise what the portal shows, never how it learns it,
      # and the request itself goes out through the contract.
      def show
        resolved = DirectoryLookup::ResolveAll.call(procedure_code: code, country_code: provider_country_code)
        @procedure = procedure_wording(resolved.requirements)
        @requirements = resolved.resolutions.map { |lookup| DemoResolutionWording.new(lookup) }

        remember_demo_names(@procedure, @requirements)
      end

      private

      # The button of one card, in whatever state the session this page is
      # reloaded from puts it: a reload is not a new request, so a requirement
      # already under way opens on its waiting rather than on a button that
      # would start a second.
      def demo_request_zone(wording)
        DemoRequestZoneComponent.new(outcome: demo_outcome_for(wording.requirement_uuid),
          requirement_uuid: wording.requirement_uuid)
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

      def code = ::Demo::RequestEvidence::PROCEDURE_CODE

      # The jurisdiction the evidence is sought in, named as the card has to name
      # it when nothing is published there. The code and the name travel apart,
      # and not the box around them: a ViewComponent instance is single-use, and
      # a card names the country more than once.
      def provider_country_code = ::Demo::RequestEvidence::PROVIDER_COUNTRY

      # In English, like the page. A code list that says nothing leaves the name
      # blank, and the box then shows the code alone.
      def provider_country_name
        @provider_country_name ||= code_lists.country_names(lang: :en)[provider_country_code]
      end

      # One client for the page, as `Admin::CommonServices::BaseController` keeps
      # one for its section: the lists it answers are the same on every call, and
      # a second instance would fetch them again.
      def code_lists = @code_lists ||= CodeListClient.new

      def report_unreachable_directories(error)
        @unreachable = error.message
        @procedure = procedure_wording(nil)
        @requirements = []

        render :show, status: :bad_gateway
      end
    end
  end
end
