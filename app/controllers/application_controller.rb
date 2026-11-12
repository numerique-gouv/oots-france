class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  helper_method :admin_section?, :presentation_page?

  # The header's navigation belongs to the administration space, and shows on
  # its pages alone.
  def admin_section? = false

  # The header of the public site carries the anchors of the presentation
  # page, the contact and the way into the administration space.
  def presentation_page? = false
end
