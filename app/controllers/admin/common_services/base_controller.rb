module Admin
  module CommonServices
    # The pages reading the central directories.
    #
    # Unlike the rest of the administration space, which reads the local
    # database, these make the application call the Commission: each query is
    # bounded by `DELAI_MAX_SERVICES_COMMUNS` and its answer cached for
    # `DUREE_CACHE_SERVICES_COMMUNS`.
    #
    # A directory refusing is information here, not a failure — showing it is
    # what these pages are for — so a refusal is rendered rather than raised:
    # the section's own page, the fragment alone on the two served in two parts,
    # or the page being read where it keeps a rescue of its own. A directory
    # unreachable is a failure, and says so in its status.
    class BaseController < Admin::BaseController
      # This answers for every page of the section. The two served in two parts
      # rescue for themselves, having made room for an answer with no page
      # around it — as the providers' page next door already does.
      rescue_from CommonServicesError, with: :render_refusal

      helper_method :requirement, :country_names, :named_country, :flagged, :in_country, :procedure_names,
        :named_procedure, :procedure_hint, :full_named_procedure, :declaration_summary

      private

      # The two pages that sweep the catalogue are served in two parts: without
      # this parameter, the page is its heading and the place
      # `DeferredContentComponent` holds, and nothing goes out to the
      # directories; with it, the sweep runs and only the listing comes back,
      # which the page has already made room for. The parameter is never typed
      # by hand — the server writes the address the controller fetches.
      def listing_asked? = params[:listing].present?

      # What these two pages answer to their own second request. The header is
      # what tells `deferred_controller.js` that the body is ours to splice into
      # the page: a status cannot say that much, nginx writing a `502` out of
      # its own pocket when nothing answers behind it.
      def render_fragment(partial, status: :ok)
        response.set_header('Deferred-Fragment', '1')

        render partial:, status:
      end

      def code_lists = @code_lists ||= CodeListClient.new

      def country_names = @country_names ||= code_lists.country_names

      # For a heading, which cannot carry a label: a `<p>` has no business
      # inside an `<h2>`. The rule itself belongs to the component.
      def named_country(code) = CountryTagComponent.label(code, country_names[code])

      # The flag alone before what a heading is about: the country is named in
      # the breadcrumb just above, and spelling it out again would say it twice
      # on one screen.
      def flagged(code, subject) = [CountryTagComponent.flag(code), subject].compact.join(' ')

      def wording
        @wording ||= CountryWording.new(names: country_names, articles: code_lists.country_articles)
      end

      def in_country(code) = wording.in(code)

      def named_or_code(code) = wording.named(code)

      def declaration_summary(**) = wording.declaration(**)

      def catalogue = @catalogue ||= Directories::Catalogue.new

      def evidence_broker = @evidence_broker ||= EvidenceBrokerClient.new

      def data_service_directory = @data_service_directory ||= DataServiceDirectoryClient.new

      # The wording of a procedure code, which the directory does not publish:
      # it returns the code alone, and the wording lives in the code list.
      def procedure_names = @procedure_names ||= code_lists.procedure_names

      def named_procedure(code) = ProcedureComponent.label(code, procedure_names[code])

      def procedure_hint(code) = ProcedureComponent.hint(procedure_names[code])

      def full_named_procedure(code) = ProcedureComponent.label(code, procedure_names[code], limit: nil)

      # Both ways down to this page — by procedure, by country — put the same
      # question to it; only the breadcrumb tells them apart.
      def read_declarations
        @country = params[:country_code]
        @procedure = found!(catalogue.procedure(params[:procedure_code]))
        @requirements = @procedure.declared_requirements(@country)
      end

      # The two pages that live under a requirement find it the same way, and
      # put the same question to it.
      def requirement = @requirement ||= found!(catalogue.requirement(params[:requirement_id]))

      # No country is named: the parameter is optional on this query, and the
      # response then carries every country's combinations at once.
      def evidence_type_lists
        @evidence_type_lists ||= evidence_broker.evidence_type_lists(requirement_id: requirement.id)
      end

      # A 404 for something that never was a record: `RecordNotFound` is what
      # Rails maps to that status, and an unknown procedure is answered here
      # exactly as an unknown exchange is next door.
      def found!(entry)
        raise ActiveRecord::RecordNotFound if entry.nil?

        entry
      end

      # `listing:` is named by the action that rescued, and never derived from
      # the parameter: `rescue_from` binds this to every page of the section,
      # and reading `params` here would answer `?listing=1` appended to any
      # other address with a fragment nothing has made room for.
      def render_refusal(error, listing: false)
        @error = error
        status = error.code.present? ? :ok : :bad_gateway
        refus = 'admin/common_services/refus'

        # The alert alone where the listing was expected: the breadcrumb and the
        # heading are already on the reader's screen, and a page would put a
        # second set underneath them.
        return render_fragment(refus, status:) if listing

        render refus, status:
      end
    end
  end
end
