# What turns a controller of the console's demonstration into one of the public
# site's: the same action, without the guard of the console, under the header of
# the public site, and reading the journey, the identity and the FranceConnect+
# of the public entrance.
module PublicDemonstration
  extend ActiveSupport::Concern

  included do
    skip_before_action :require_administrator
  end

  def admin_section? = false

  def presentation_page? = true

  private

  def demo_entrance = Demo::Entrance::PUBLIC
end
