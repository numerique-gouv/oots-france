# The exchange the demonstration's session is following, and the one condition
# the tracking page and the download both refuse to render without.
#
# Chapter 1 §4.2: « Any evidences that are returned in response are made
# available to the specific procedure end-user that issued the query for those
# evidences. » The session is what says which user issued which query, so the
# identifier is read from there and never from the request — a page taking it
# from a parameter would serve whoever guessed a UUID.
module HoldsDemoExchange
  extend ActiveSupport::Concern

  included do
    before_action :require_exchange
  end

  private

  def exchange_id = session[:demo_exchange]

  # `defined?` and not `||=`: a session following an exchange the register does
  # not carry must ask once and be answered `nil` once.
  def demo_request
    return @demo_request if defined?(@demo_request)

    @demo_request = ::Demo::Request.find_by(exchange_id:)
  end

  # Back to the form, which is where a journey with no exchange behind it
  # resumes: the identity is still good, only the request has yet to be made.
  def require_exchange
    redirect_to admin_demo_demande_path if demo_request.nil?
  end
end
