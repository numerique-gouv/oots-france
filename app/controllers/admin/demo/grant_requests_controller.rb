module Admin
  module Demo
    # The second page of the demonstration: the grant application form, carrying
    # the identity the authentication attested.
    #
    # It shows those attributes and offers no field on them — chapter 2.2 §2
    # makes the portal answerable for the identity in the request matching the
    # one the eID means yielded, and the demonstration holds that by not letting
    # them be typed. The fields it does offer are the application's own, and
    # nothing reads them: `RG7` of the ticket has them neither kept nor sent.
    #
    # `create` is where the explicit request of chapter 1 §3.3 is read — « a
    # step in which the user is asked to express explicitly whether he or she
    # wants to use the Once-Only Technical System ». Withheld, the journey stops
    # on a page saying the evidence has to come by another route: nothing is
    # resolved, nothing is asked, no exchange exists.
    class GrantRequestsController < Admin::BaseController
      include HoldsDemoIdentity

      # The one value that counts as the explicit request. Anything else — the
      # refusal, an unanswered form, a value nobody sent — is the absence of it,
      # which is the reading the chapter's « whether » asks for.
      EXPRESS_REQUEST = 'oui'.freeze

      helper_method :express_request

      def show
        @wording = DemoIdentityWording.new(identity)
      end

      def create
        return redirect_to(admin_demo_confirmation_path) if express_request_given?

        render :create
      end

      private

      # Read by the form, so that the value the radio sends and the value this
      # action recognises cannot part company.
      def express_request = EXPRESS_REQUEST

      def express_request_given? = params[:oots] == EXPRESS_REQUEST
    end
  end
end
