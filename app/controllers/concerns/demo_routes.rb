# The addresses of the demonstration procedure, under the entrance the request
# came in by: the walk is drawn twice in `config/routes.rb`, and each page leads
# to the next under its own entrance. The console's wherever nothing says
# otherwise — `PublicDemonstration` does.
module DemoRoutes
  extend ActiveSupport::Concern

  included do
    helper_method :demo_entrance, :demo_path, :public_demonstration?
  end

  private

  def demo_entrance = Demo::Entrance::CONSOLE

  def public_demonstration? = demo_entrance.public?

  # `demo_path(:documents)` is `admin_demo_documents_path` under the console and
  # `demonstration_documents_path` on the public site, the segments of the
  # current address recalled the same way.
  def demo_path(page, entrance: demo_entrance, **)
    public_send(:"#{entrance.route_prefix}_#{page}_path", **)
  end
end
