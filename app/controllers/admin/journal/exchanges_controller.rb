module Admin
  module Journal
    class ExchangesController < BaseController
      def show
        @exchange = Exchange.find_by!(exchange_id: params.expect(:id))
        @events = @exchange.audit_events.to_a
      end
    end
  end
end
