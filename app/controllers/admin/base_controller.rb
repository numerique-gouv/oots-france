module Admin
  # The administration space, which observes and never writes: it reads what
  # the exchanges have already recorded and offers no action on them. Two
  # corners act: the demonstration procedure of `Admin::Demo`, playing a portal
  # rather than reading a log, and the connectivity tests of
  # `Admin::CommonServices::ConnectivityTestsController`, which send a test message and open no
  # exchange — `docs/espace_administration.md` says why both sit here.
  class BaseController < ApplicationController
    include AdminAuthentication

    def admin_section? = true
  end
end
