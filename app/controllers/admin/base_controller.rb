module Admin
  # The administration space, which observes and never writes: it reads what
  # the exchanges have already recorded and offers no action on them.
  class BaseController < ApplicationController
    include AdminAuthentication

    def admin_section? = true
  end
end
