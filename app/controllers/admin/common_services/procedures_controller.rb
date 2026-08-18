module Admin
  module CommonServices
    class ProceduresController < BaseController
      # Rendue en entier : les codes publiés tiennent dans une page, et le champ
      # de recherche les filtre côté navigateur.
      def index
        @procedures = catalogue.procedures
      end

      # Les pays qui ont déclaré cette démarche, et rien d'autre : ce que chacun
      # en tire se lit sur sa page.
      def show
        @procedure = found!(catalogue.procedure(params[:code]))
      end

      # La même page que `countries#procedure`, atteinte par l'autre bout.
      def country = read_declarations
    end
  end
end
