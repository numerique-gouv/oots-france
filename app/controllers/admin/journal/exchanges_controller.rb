module Admin
  module Journal
    class ExchangesController < BaseController
      def index
        @filter = ExchangeFilter.from(params)
        scope = Exchange.all

        @total = @filter.total(scope)
        @page = @filter.page_within(@total)
        @exchanges = @filter.apply(scope, @page)
      end

      def show
        @exchange = Exchange.find_by!(exchange_id: params.expect(:id))
        @events = @exchange.audit_events.to_a
      end
    end
  end
end
