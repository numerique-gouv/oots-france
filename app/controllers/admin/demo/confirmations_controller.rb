module Admin
  module Demo
    # The last page before an exchange exists, and the press that opens one.
    #
    # `show` carries the identity the authentication attested — shown and never
    # typed, chapter 2.2 §2 making the portal answerable for the identity in the
    # request matching the one the eID means yielded — and names the evidence
    # provider and the evidence type, which requirement 27 of chapter 1 §2 asks
    # for word for word — « The user is provided with information about name of
    # evidence provider and evidence type for confirmation, before any request
    # is made. » Unable to name them, it offers nothing to confirm: the
    # requirement is a condition of the request, not a decoration on it.
    #
    # `create` **is** the explicit request, and the request leaves as it is
    # pressed. Chapter 4.5.1 §2.7 ties the two: « If the value of this slot is
    # true, the value of the IssueDateTime slot shall not be materially
    # different from the date and time at which the explicit request was made by
    # the user. »
    #
    # The press is also where the explicit request of chapter 1 §3.3 is made —
    # « a step in which the user is asked to express explicitly whether he or
    # she wants to use the Once-Only Technical System ». The page asks it as one
    # gesture rather than as a question with two answers: the way out is the
    # link beside the button, and nothing leaves unless the button is pressed.
    #
    # A request that leaves ends the page: the user is sent to the tracking,
    # which is where the answer will appear and the only address of the journey
    # worth reloading. A refusal stays here, there being no exchange to follow.
    class ConfirmationsController < Admin::BaseController
      include HoldsDemoIdentity

      # A directory that refuses says so with a code and stays on the page; one
      # that cannot be reached carries none, and `DirectoryLookup::Refusing`
      # re-raises it. Rescued here for the same reason the console's directory
      # pages rescue it: the operator reads what happened rather than a 500.
      rescue_from CommonServicesError, with: :report_unreachable_directories

      def show
        @identity_wording = DemoIdentityWording.new(identity)
        @wording = DemoResolutionWording.new(lookup)
      end

      def create
        result = ::Demo::RequestEvidence.call(identity:, conversation_id: reusable_conversation)

        return refuse(result) unless result.success?

        keep(result)

        redirect_to admin_demo_suivi_path
      end

      private

      def keep(result)
        # Chapter 4.4 §4.3.2: the conversation is « reused for combined flows »
        # and « MUST NOT be reused if the user authenticates with a different
        # identity ». The pseudonym FranceConnect+ hands this service provider
        # is what tells one identity from another, so it is stored beside the
        # conversation and compared before the conversation is offered again.
        session[:demo_conversation] = { id: result.conversation_id, subject: identity.subject }
        # What the tracking page follows. The session and nothing else: it is
        # what chapter 1 §4.2 makes the evidence available to.
        session[:demo_exchange] = result.exchange_id
      end

      def refuse(result)
        @failure = result.error

        render :create
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
