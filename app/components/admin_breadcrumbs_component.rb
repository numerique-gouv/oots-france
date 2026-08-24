# The trail every page of a section of the console hangs from.
#
# The two first crumbs are the same on all the pages of a section, and the last
# one is where the reader stands: it carries no link, which is what tells the
# DSFR to mark it as current.
#
# The DSFR component is rendered directly: the `dsfr_breadcrumbs` helper is put
# on ActionView, and a ViewComponent does not inherit from it.
class AdminBreadcrumbsComponent < ViewComponent::Base
  def initialize(trail: [])
    @trail = trail
    super()
  end

  def call
    render(DsfrComponent::BreadcrumbsComponent.new) do |trail|
      crumbs.each { |label, href| trail.with_breadcrumb(label:, href:) }
    end
  end

  private

  def section = raise(NotImplementedError)

  def crumbs
    walked = [[t('components.admin_breadcrumbs.admin'), helpers.admin_root_path], section, *@trail]

    walked[..-2] + [[walked.last.first, nil]]
  end
end
