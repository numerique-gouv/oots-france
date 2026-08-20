module Admin
  module CommonServices
    class ProceduresController < BaseController
      # Rendered whole: the published codes fit on one page, and the search
      # field filters them in the browser.
      def index
        @procedures = catalogue.procedures
      end

      # The countries that declared this procedure, and nothing else: what each
      # requires of it is read on its own page.
      def show
        @procedure = found!(catalogue.procedure(params[:code]))
      end

      # The same page as `countries#procedure`, reached from the other end.
      def country = read_declarations
    end
  end
end
