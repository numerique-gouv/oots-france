# The trail the pages of the central directories hang from.
class DirectoryBreadcrumbsComponent < AdminBreadcrumbsComponent
  private

  def section
    [t('components.directory_breadcrumbs.directories'), helpers.admin_common_services_root_path]
  end
end
