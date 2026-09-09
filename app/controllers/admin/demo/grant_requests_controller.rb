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
      def show
        @identity = ::Demo::UserIdentity.from_session(session[:demo_identity])

        return redirect_to(admin_demo_root_path) if @identity.nil?

        @wording = DemoIdentityWording.new(@identity)
      end
    end
  end
end
