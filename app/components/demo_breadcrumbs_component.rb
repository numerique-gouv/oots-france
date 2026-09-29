# The trail of the demonstration, which follows the segments of its address:
# the screen the line is chosen on, then — on every page of the walk — the line
# itself, leading to its sign-in page, then the page being read.
#
# `specification` is the line the address names, `nil` on the screen that names
# none.
class DemoBreadcrumbsComponent < AdminBreadcrumbsComponent
  def initialize(specification: nil, trail: [])
    @specification = specification
    super(trail:)
  end

  private

  def section = [t('components.demo_breadcrumbs.demo'), helpers.admin_demo_root_path]

  def sections = [section, *line]

  def line
    return [] if @specification.nil?

    [[@specification.number, helpers.admin_demo_home_path(version: @specification.segment)]]
  end
end
