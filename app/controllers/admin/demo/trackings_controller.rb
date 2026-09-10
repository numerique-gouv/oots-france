module Admin
  module Demo
    # The last page of the demonstration: what the request obtained, read back
    # from the contract.
    #
    # It reads and opens nothing. Chapter 4.4 §4.1 — « to return more references
    # to the Online Procedure Portal, even if it is for the same user in the same
    # session, for the same evidency type and data service, a new unique request
    # MUST be issued » — so consulting is never asking, and a user who wants
    # another answer walks the journey again.
    class TrackingsController < Admin::BaseController
      include HoldsDemoIdentity
      include HoldsDemoExchange

      # The contract unreachable is not an outcome of the exchange: the page says
      # so rather than presenting an outage as an answer, and the operator reads
      # what happened rather than a 500.
      rescue_from DemoContractError, with: :report_unreachable_contract

      def show
        @wording = DemoOutcomeWording.new(answer: state_client.fetch(exchange_id), request: demo_request)
      end

      private

      def state_client = @state_client ||= ::Demo::ExchangeStateClient.new

      def report_unreachable_contract(error)
        @unreachable = error.message
        @wording = DemoOutcomeWording.unanswered(request: demo_request)

        render :show, status: :bad_gateway
      end
    end
  end
end
