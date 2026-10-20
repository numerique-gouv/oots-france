# The trail of the demonstration, which follows the segments of its address:
# the screen the line is chosen on, then the line, leading to the screen its
# procedure is chosen on, then — on every page of the walk — the procedure,
# leading to its sign-in page, then the page being read.
#
# `specification` is the line the address names and `procedure` the code of the
# procedure, each `nil` on a screen whose address names none.
class DemoBreadcrumbsComponent < AdminBreadcrumbsComponent
  def initialize(specification: nil, procedure: nil, trail: [])
    @specification = specification
    @procedure = procedure
    super(trail:)
  end

  private

  def section = [t('components.demo_breadcrumbs.demo'), helpers.admin_demo_root_path]

  def sections = [section, *line, *procedure]

  def line
    return [] if @specification.nil?

    [[@specification.number, helpers.admin_demo_procedures_path(version: @specification.segment)]]
  end

  def procedure
    return [] if @specification.nil? || @procedure.nil?

    [[t('components.demo_breadcrumbs.procedure', code: @procedure),
      helpers.admin_demo_home_path(version: @specification.segment, procedure: @procedure)]]
  end
end
