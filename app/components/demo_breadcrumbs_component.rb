# The trail of the demonstration, which follows the segments of its address:
# the screen the line is chosen on, then the line, leading to the screen its
# procedure is chosen on, then — on every page of the walk — the procedure,
# leading to its sign-in page, then the page being read.
#
# `specification` is the line the address names and `procedure` the code of the
# procedure, each `nil` on a screen whose address names none. `sign_out` is the
# address the sign-out of FranceConnect+ submits to and `identity` the one it
# closes, both `nil` while the entrance holds no walk: with them, the trail
# shares its line with the button, which names the user.
class DemoBreadcrumbsComponent < AdminBreadcrumbsComponent
  def initialize(specification: nil, procedure: nil, trail: [], sign_out: nil, identity: nil)
    @specification = specification
    @procedure = procedure
    @sign_out = sign_out
    @identity = identity
    super(trail:)
  end

  def call
    return super if @sign_out.nil?

    tag.div(class: 'fr-grid-row fr-grid-row--top') do
      tag.div(super, class: 'fr-col') + tag.div(sign_out_button, class: 'fr-col-auto fr-mt-1w')
    end
  end

  private

  # The gesture of the button of the identity card, leading to the same place,
  # showing whom it signs out: the name is what the user reads, the sign-out
  # what the button is named.
  def sign_out_button
    label = t('components.demo_breadcrumbs.sign_out', name: user_name)

    button_to user_name, @sign_out, method: :delete,
      class: 'fr-btn fr-btn--sm fr-btn--tertiary fr-btn--icon-left fr-icon-logout-box-r-line',
      title: label, aria: { label: }
  end

  def user_name
    @user_name ||= t('components.demo_breadcrumbs.user_name', given_name: @identity.given_name, family_name: @identity.family_name).squish
  end

  # The public entrance climbs to the front page of the site: its visitor has
  # no console to reach.
  def home
    return super unless helpers.public_demonstration?

    [t('components.demo_breadcrumbs.home'), helpers.root_path]
  end

  def section = [t('components.demo_breadcrumbs.demo'), helpers.demo_path(:root)]

  def sections = [section, *line, *procedure]

  def line
    return [] if @specification.nil?

    [[@specification.number, helpers.demo_path(:procedures, version: @specification.segment)]]
  end

  def procedure
    return [] if @specification.nil? || @procedure.nil?

    [[t('components.demo_breadcrumbs.procedure', code: @procedure),
      helpers.demo_path(:home, version: @specification.segment, procedure: @procedure)]]
  end
end
