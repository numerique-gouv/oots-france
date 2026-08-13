class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  helper_method :admin_section?

  # The header's navigation belongs to the administration space. Elsewhere
  # there is nowhere to navigate to that the page does not already offer.
  def admin_section? = false
end
