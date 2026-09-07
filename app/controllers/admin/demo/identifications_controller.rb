module Admin
  module Demo
    # Where the single sign-in button of the demonstration leads. The European
    # flow of FranceConnect+ — the `/authorize` call carrying
    # `idp_hint=eidas-bridge`, and everything it brings back — is OOTS-179,
    # which replaces this page with it.
    class IdentificationsController < Admin::BaseController
      def show; end
    end
  end
end
