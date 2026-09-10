module Admin
  module Demo
    # The last page before an exchange exists, and the press that opens one.
    #
    # `show` names the evidence provider and the evidence type, which requirement
    # 27 of chapter 1 §2 asks for word for word — « The user is provided with
    # information about name of evidence provider and evidence type for
    # confirmation, before any request is made. » Unable to name them, it offers
    # nothing to confirm: the requirement is a condition of the request, not a
    # decoration on it.
    #
    # `create` **is** the explicit request, and the request leaves as it is
    # pressed. Chapter 4.5.1 §2.7 ties the two: « If the value of this slot is
    # true, the value of the IssueDateTime slot shall not be materially
    # different from the date and time at which the explicit request was made by
    # the user. »
    #
    # It renders rather than redirects, for want of a page to redirect to: where
    # the user follows the exchange is OOTS-182.
    class ConfirmationsController < Admin::BaseController
      include HoldsDemoIdentity

      # A directory that refuses says so with a code and stays on the page; one
      # that cannot be reached carries none, and `DirectoryLookup::Refusing`
      # re-raises it. Rescued here for the same reason the console's directory
      # pages rescue it: the operator reads what happened rather than a 500.
      rescue_from CommonServicesError, with: :report_unreachable_directories

      def show
        @wording = DemoResolutionWording.new(lookup)
      end

      def create
        result = ::Demo::RequestEvidence.call(identity:, conversation_id: reusable_conversation)

        if result.success?
          keep(result)
        else
          @failure = result.error
        end

        render :create
      end

      private

      def keep(result)
        # Chapter 4.4 §4.3.2: the conversation is « reused for combined flows »
        # and « MUST NOT be reused if the user authenticates with a different
        # identity ». The pseudonym FranceConnect+ hands this service provider
        # is what tells one identity from another, so it is stored beside the
        # conversation and compared before the conversation is offered again.
        session[:demo_conversation] = { id: result.conversation_id, subject: identity.subject }
        @exchange_id = result.exchange_id
        @conversation_id = result.conversation_id
      end

      def reusable_conversation
        held = session[:demo_conversation].presence&.symbolize_keys
        return nil if held.nil? || held[:subject] != identity.subject

        held[:id]
      end

      # The chain the console already replays on `/admin/common_services/resolution`,
      # and the one a request walks before sending anything. Replayed here for
      # the screen alone: the TDD normalise what the portal shows, never how it
      # learns it, and the request itself goes out through the contract.
      def lookup
        DirectoryLookup::Resolve.call(
          evidence_broker: EvidenceBrokerClient.new, data_service_directory: DataServiceDirectoryClient.new,
          procedure_code: ::Demo::RequestEvidence::PROCEDURE_CODE,
          country_code: ::Demo::RequestEvidence::PROVIDER_COUNTRY,
        )
      end

      def report_unreachable_directories(error)
        @unreachable = error.message

        render :show, status: :bad_gateway
      end
    end
  end
end
