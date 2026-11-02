# The DSFR header, with the labels its gem writes in French translated, and the
# language selector in its tools beside the quick access links, where the
# DSFR's `header-tools.ejs` places it. The gem's slots are kept; only the
# template is the application's.
class SiteHeaderComponent < DsfrComponent::HeaderComponent
  private

  # The selector is on every page, and the menu is what carries it below the
  # DSFR's large breakpoint.
  def with_tools? = true

  def with_menu? = true
end
