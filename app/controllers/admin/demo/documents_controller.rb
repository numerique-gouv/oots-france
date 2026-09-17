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
    # The press itself, and what becomes of it, belong to `RequestsController`.
    # This page renders one zone per requirement it can name, each in whatever
    # state the session it is reloaded from puts it: chapter 4.4 §4.2.2 has
    # « different basic flows … executed sequentially and/or in parallel », so
    # no card waits on its neighbour.
    class DocumentsController < Admin::BaseController
      include HoldsDemoIdentity
      include ReadsDemoRequest

      # A directory that refuses says so with a code and stays on the page; one
      # that cannot be reached carries none, and `DirectoryLookup::Refusing`
      # re-raises it. Rescued here for the same reason the console's directory
      # pages rescue it: the operator reads what happened rather than a 500.
      rescue_from CommonServicesError, with: :report_unreachable_directories

      helper_method :provider_country_code, :provider_country_name, :demo_request_zone

      # The identity is the one thing on this page no directory has to answer
      # for, and the rescue below renders the same template.
      def show
        leading = lookup
        @procedure = procedure_wording(leading.requirements)
        @requirements = resolutions(leading).map { |resolved| DemoResolutionWording.new(resolved) }

        remember_what_is_named
      end

      private

      # What requirement 27 had this page show, kept for the press that follows:
      # the zone says it again, and reading it back there rather than resolving
      # it again keeps three directory queries off an address made to be asked
      # over and over.
      #
      # One entry per card that can be pressed, under the UUID its address
      # carries — a press files what its own card named, never a neighbour's.
      # Whatever a card cannot name it cannot offer to confirm, so it is not
      # here either.
      def remember_what_is_named
        session[:demo_procedure] = { title: @procedure.title, title_language: @procedure.title_language }
        session[:demo_named] = @requirements.select(&:nameable?)
          .to_h { |wording| [wording.requirement_uuid, what_the_card_names(wording)] }
      end

      # The title of the procedure is not among them: it stands once at the top
      # of the page, belongs to no requirement, and repeating it under each
      # would swell a session the cookie store bounds at four kibibytes.
      def what_the_card_names(wording)
        { evidence_type: wording.evidence_type, evidence_type_language: wording.evidence_type_language,
          provider: wording.provider, provider_language: wording.provider_language,
          requirement_id: wording.requirement_id, requirement: wording.requirement,
          requirement_language: wording.requirement_language }
      end

      # The press of one card, in whatever state the session this page is
      # reloaded from puts it: a reload is not a new request, so a requirement
      # already under way opens on its waiting rather than on a button that
      # would start a second.
      def demo_request_zone(wording)
        DemoRequestZoneComponent.new(outcome: demo_outcome_for(wording.requirement_uuid),
          requirement_uuid: wording.requirement_uuid)
      end

      # The chain the console already replays on `/admin/common_services/resolution`,
      # and the one a request walks before sending anything. Replayed here for
      # the screen alone: the TDD normalise what the portal shows, never how it
      # learns it, and the request itself goes out through the contract.
      def lookup(requirement_id = nil)
        DirectoryLookup::Resolve.call(
          evidence_broker: EvidenceBrokerClient.new, data_service_directory: DataServiceDirectoryClient.new,
          procedure_code: ::Demo::RequestEvidence::PROCEDURE_CODE,
          country_code: ::Demo::RequestEvidence::PROVIDER_COUNTRY, requirement_id:,
        )
      end

      # One resolution per requirement the procedure rests on, the page offering
      # a card for each. The first is the one already walked — its own step read
      # the whole list — and the others are asked for by identifier, which is
      # what the console's resolution page does. The Evidence Broker answer they
      # share is cached, so each costs the two queries below it and no more.
      def resolutions(leading)
        Array(leading.requirements).map do |requirement|
          requirement.uuid == leading.requirement&.uuid ? leading : lookup(requirement.uuid)
        end
      end

      # The heading the home page stands under, said again here: the two are one
      # journey, and the procedure is what it is about. Built on the requirements
      # the resolution has already read — its first step asks the very question
      # the home page asks — so the page learns it without a query of its own.
      def procedure_wording(requirements)
        DemoProcedureWording.new(
          code:, requirements:, published_name: CodeListClient.new.procedure_names(lang: :en)[code],
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
        @provider_country_name ||= CodeListClient.new.country_names(lang: :en)[provider_country_code]
      end

      def report_unreachable_directories(error)
        @unreachable = error.message
        @procedure = procedure_wording(nil)
        @requirements = []

        render :show, status: :bad_gateway
      end
    end
  end
end
