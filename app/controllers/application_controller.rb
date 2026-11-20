class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  include DemoRoutes

  helper_method :admin_section?, :presentation_page?

  # The header's navigation belongs to the administration space, and shows on
  # its pages alone.
  def admin_section? = false

  # The header of the public site carries the anchors of the presentation
  # page, the contact and the way into the administration space.
  def presentation_page? = false

  private

  # Unreadable to a script; Lax lets a top-level navigation back from an
  # identity provider carry it.
  def keep_encrypted(name, value)
    cookies.encrypted[name] = { value:, httponly: true, same_site: :lax }
  end

  # The cookies kept beside the session go with it: an identity, a departure or
  # a verdict outliving a sign-out or a new sign-in would carry one agent's walk
  # over to the next.
  def reset_session
    super
    (DemoIdentityCookie::COOKIES + RecognisesPreviewIdentity::COOKIES).each { |name| cookies.delete(name) }
  end
end
