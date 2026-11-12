# Who the console's session says the reader is, without closing anything: what
# `AdminAuthentication` guards the console with, and what a public page asks
# to show the administrator alone what is theirs.
module RecognisesAdministrator
  extend ActiveSupport::Concern

  included do
    helper_method :signed_in_email, :named_administrator?
  end

  private

  # The agent the sign-in identified, admitted again at every request rather
  # than once at the sign-in: a domain taken out of `DOMAINES_AGENTS_PROCONNECT`,
  # or an invitation withdrawn, closes the sessions it had opened at their next
  # page.
  def administrator_signed_in?
    email = session[:agent_email]

    email.present? && Agent.new(email:).admitted?
  end

  # Read in the list at every request, so that naming or dismissing an agent in
  # a console takes effect at their next page.
  def named_administrator?
    return @named_administrator if defined?(@named_administrator)

    @named_administrator = administrator_signed_in? && Administrator.appointed?(signed_in_email)
  end

  # The address of the agent the session admitted, which the header shows.
  def signed_in_email = session[:agent_email]
end
