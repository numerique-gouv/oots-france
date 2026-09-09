module Admin
  module Demo
    # The second page of the demonstration: the grant application form, carrying
    # the identity the authentication attested.
    #
    # It shows those attributes and offers no field on them — chapter 2.2 §2
    # makes the portal answerable for the identity in the request matching the
    # one the eID means yielded, and the demonstration holds that by not letting
    # them be typed. What the application itself asks, and its sending, are
    # OOTS-181.
    class GrantRequestsController < Admin::BaseController
      # The same validity on the way out as on the way in: what
      # `Demo::CompleteIdentification` refused to hold, this page refuses to
      # show. A session written under an earlier shape would otherwise render as
      # a form with blank rows, which no layer would notice.
      def show
        @identity = ::Demo::UserIdentity.from_session(session[:demo_identity])

        return redirect_to(admin_demo_root_path) unless @identity&.valid?

        @wording = DemoIdentityWording.new(@identity)
      end
    end
  end
end
