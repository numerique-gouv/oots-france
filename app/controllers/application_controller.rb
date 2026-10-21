class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  helper_method :admin_section?, :admin_space_link?

  # The header's navigation belongs to the administration space, and shows on
  # its pages alone.
  def admin_section? = false

  def admin_space_link? = false
end
