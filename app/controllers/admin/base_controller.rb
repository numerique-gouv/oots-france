module Admin
  # The administration space, which observes and never writes: it reads what
  # the exchanges have already recorded and offers no action on them. The
  # demonstration procedure of `Admin::Demo` is the one corner that observes
  # nothing, playing a portal rather than reading a log —
  # `docs/espace_administration.md` says why it sits here nonetheless.
  class BaseController < ApplicationController
    include AdminAuthentication

    def admin_section? = true
  end
end
