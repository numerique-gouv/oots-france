# The jobs dashboard is a mounted engine, so no `before_action` of this
# application reaches it — and it is the one page of the space that acts,
# offering its own retry and discard buttons. GoodJob publishes this load hook
# for exactly this purpose; it runs at the end of its controller's class body,
# hence before any of its subclasses, which therefore inherit the filter.
#
# `GoodJob::FrontendsController` is the exception: it descends from
# ActionController::Base directly, so the CSS, JavaScript and icons the gem
# serves under /admin/jobs/frontend stay reachable without a session. They carry
# no data of ours.
ActiveSupport.on_load(:good_job_application_controller) do
  include AdminAuthentication
end
