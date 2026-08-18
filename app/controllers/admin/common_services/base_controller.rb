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
    # what these pages are for — so a refusal renders as a page. A directory
    # unreachable is a failure, and says so in its status.
    class BaseController < Admin::BaseController
      rescue_from CommonServicesError, with: :render_refusal

      helper_method :requirement, :country_names, :named_country, :in_country, :procedure_names,
        :named_procedure, :procedure_hint, :full_named_procedure, :declaration_summary

      private

      def code_lists = @code_lists ||= CodeListClient.new

      def country_names = @country_names ||= code_lists.country_names

      # Pour un titre, qui ne peut pas porter d'étiquette : un `<p>` n'a rien à
      # faire dans un `<h2>`. La règle, elle, est celle du composant.
      def named_country(code) = CountryTagComponent.label(code, country_names[code])

      def wording
        @wording ||= CountryWording.new(names: country_names, articles: code_lists.country_articles)
      end

      def in_country(code) = wording.in(code)

      def named_or_code(code) = wording.named(code)

      def declaration_summary(**) = wording.declaration(**)

      def catalogue = @catalogue ||= Directories::Catalogue.new

      def evidence_broker = @evidence_broker ||= EvidenceBrokerClient.new

      def data_service_directory = @data_service_directory ||= DataServiceDirectoryClient.new

      # Les intitulés des codes de démarche, que l'annuaire ne publie pas : il
      # ne rend que le code, et son intitulé vit dans la liste de codes.
      def procedure_names = @procedure_names ||= code_lists.procedure_names

      def named_procedure(code) = ProcedureComponent.label(code, procedure_names[code])

      def procedure_hint(code) = ProcedureComponent.hint(procedure_names[code])

      def full_named_procedure(code) = ProcedureComponent.label(code, procedure_names[code], limit: nil)

      # Les deux descentes vers cette page — par la démarche, par le pays — lui
      # posent la même question ; seul le fil d'Ariane les distingue.
      def read_declarations
        @country = params[:country_code]
        @procedure = found!(catalogue.procedure(params[:procedure_code]))
        @requirements = @procedure.declared_requirements(@country)
      end

      # Les deux pages qui vivent sous une exigence la retrouvent de la même
      # façon, et lui posent la même question.
      def requirement = @requirement ||= found!(catalogue.requirement(params[:requirement_id]))

      # Aucun pays n'est nommé : ce paramètre est facultatif sur cette requête,
      # et la réponse porte alors les combinaisons de tous les pays à la fois.
      def evidence_type_lists
        @evidence_type_lists ||= evidence_broker.evidence_type_lists(requirement_id: requirement.id)
      end

      # A 404 for something that never was a record: `RecordNotFound` is what
      # Rails maps to that status, and an unknown procedure is answered here
      # exactly as an unknown conversation is next door.
      def found!(entry)
        raise ActiveRecord::RecordNotFound if entry.nil?

        entry
      end

      def render_refusal(error)
        @error = error
        status = error.code.present? ? :ok : :bad_gateway

        render 'admin/common_services/refus', status:
      end
    end
  end
end
