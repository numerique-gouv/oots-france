# The DSFR breadcrumb, with the labels its gem writes in French translated.
class BreadcrumbsComponent < DsfrComponent::BreadcrumbsComponent
  private

  def default_attributes = super.merge(aria: { label: I18n.t('components.breadcrumbs.label') })
end
