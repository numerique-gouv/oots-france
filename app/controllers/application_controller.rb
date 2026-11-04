class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  helper_method :admin_section?, :presentation_page?

  # The header's navigation belongs to the administration space, and shows on
  # its pages alone.
  def admin_section? = false

  # The presentation page's header carries its anchors, its contact and the way
  # into the administration space; no other page's does.
  def presentation_page? = false
end
