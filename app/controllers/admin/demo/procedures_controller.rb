module Admin
  module Demo
    # The second screen of the demonstration: under the line chosen on the first,
    # the operator picks the procedure the walk plays, and each entry leads to
    # the sign-in page under that line and that procedure.
    #
    # It lists every code a request may name in its `Procedure` slot
    # (`R-EDM-REQ-C003`, FATAL), and nothing else. Nothing is written, as on the
    # screen before it: the address of the page an entry leads to carries the
    # choice.
    #
    # The procedures France declares to the Evidence Broker say so in their
    # footer, with the number of requirements each rests on in France, read
    # from the one catalogue answer `/admin/common_services/countries/FR/procedures`
    # reads too. A directory that cannot be reached costs those footers and that
    # grouping, and nothing else: the choice needs no directory.
    class ProceduresController < Admin::BaseController
      def index
        @specification = EdmSpecification.from_segment(params[:version])
        @requirements_declared = declared_by_france
        @procedures = ProcedureCode.ordered(declared: @requirements_declared.keys)
        @names = code_lists.procedure_names(lang: :en)
        @country_name = code_lists.country_names(lang: :en)[country]
      end

      private

      # The number of requirements France declares under each code it declares.
      def declared_by_france
        Directories::Catalogue.new.procedures_in(country).to_h { |procedure| [procedure.code, procedure.requirements.size] }
      rescue CommonServicesError => e
        Rails.logger.warn(I18n.t('controllers.admin.demo.procedures.undeclared', error: e.message))

        {}
      end

      def country = Settings.common_services_country_code

      def code_lists = @code_lists ||= CodeListClient.new
    end
  end
end
