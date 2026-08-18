module Admin
  module CommonServices
    class RequirementsController < BaseController
      # Rendues en entier : les exigences publiées tiennent dans une page, et le
      # champ de recherche les filtre côté navigateur.
      def index
        @requirements = catalogue.requirements
      end

      # Cette page n'est pas imbriquée sous une exigence : elle en nomme une par
      # `id`, là où celle des fournisseurs la reçoit en `requirement_id`.
      #
      # Aucun pays n'est nommé à l'annuaire : ce paramètre est facultatif sur
      # cette requête, et la réponse porte alors les combinaisons de tous les
      # pays à la fois. Vingt-sept au plus, que le champ de recherche filtre côté
      # navigateur.
      def show
        @requirement = found!(catalogue.requirement(params[:id]))
        @types_count = lists.sum { |list| list.evidence_types.size }
        @by_country = by_country
      end

      # Ce qui l'impose, sur une page à part : c'est l'autre rôle, et la page
      # de l'exigence répond déjà d'un bout à l'autre à la question du premier.
      def procedures
        @requirement = requirement
      end

      # Les démarches d'un seul pays requêteur. Rien n'est redemandé à
      # l'annuaire : le catalogue porte déjà les déclarations, et c'est leur
      # juridiction qui les trie.
      def country
        @requirement = requirement
        @country = params[:country_code]
        @declared = @requirement.declared_in(@country)

        found!(@declared.presence)

        # Ce que chaque démarche exige de ce pays, cette exigence comprise : le
        # catalogue le porte déjà, une carte n'en montrant qu'une seule.
        @required = @declared.filter_map(&:procedure_code).uniq.index_with do |code|
          catalogue.procedure(code).declared_requirements(@country).size
        end
      end

      private

      def lists = @lists ||= evidence_broker.evidence_type_lists(requirement_id: @requirement.id)

      def by_country = lists.group_by(&:country).sort_by { |country, _| country.to_s }
    end
  end
end
