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
      def show
        code = ProcedureCode::STUDY_FINANCING
        @procedure_label = ProcedureComponent.label(code, CodeListClient.new.procedure_names[code], limit: nil)
      end
    end
  end
end
