module Admin
  # The administration space, which observes and never writes: it reads what
  # the exchanges have already recorded and offers no action on them.
  #
  # Nothing here is behind an authentication yet — see
  # `docs/espace_administration.md` for what that costs and what closes it.
  class BaseController < ApplicationController
    def admin_section? = true
  end
end
