class DemoBreadcrumbsComponent < AdminBreadcrumbsComponent
  private

  def section
    [t('admin.demo.home.show.title'), helpers.admin_demo_root_path]
  end
end
