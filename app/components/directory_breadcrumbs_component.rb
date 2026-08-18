# The trail every page of the directories hangs from.
#
# The two first crumbs are the same on all of them, and the last one is where
# the reader stands: it carries no link, which is what tells the DSFR to mark
# it as current.
#
# The DSFR component is rendered directly: the `dsfr_breadcrumbs` helper is put
# on ActionView, and a ViewComponent does not inherit from it.
class DirectoryBreadcrumbsComponent < ViewComponent::Base
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

  def crumbs
    walked = [[t('components.directory_breadcrumbs.admin'), helpers.admin_root_path],
              [t('components.directory_breadcrumbs.directories'), helpers.admin_common_services_root_path],
              *@trail]

    walked[..-2] + [[walked.last.first, nil]]
  end
end
