# The three addresses of the demonstration procedure FranceConnect+ is given,
# and the only part of this application it reads or sends a user to.
# `docs/eidas_context.md` says why they answer to a caller holding no session.
class FranceConnectController < ApplicationController
  include RefusesIdentification

  # The « Client keys url » of the demonstration procedure. Distinct from the
  # key of `/auth/cles_publiques`, which opens the beneficiary token of a French
  # service provider — `Settings.france_connect_private_key_jwk` says why.
  def cles_publiques = render(json: PublicKeySet.new(Settings.france_connect_private_key_jwk).to_h)

  # Redirects rather than renders, whichever way it goes: an authorization code
  # is single use, and leaving in the history a page that carries one invites
  # replaying it.
  #
  # Identifying opens a journey, and the requests the session was following
  # belonged to the one before: the new journey has an identifier of its own, so
  # every zone offers the button again rather than the document the previous
  # journey obtained. The conversation is not dropped with it — chapter 4.4
  # §4.3.2 has it « SHOULD be reused for combined flows » and forbids reuse only
  # « if the user authenticates with a different identity », which `Demo::Journey`
  # compares before carrying it over.
  #
  # This is the one place the journey is written, and the instant the identity
  # exists is the earliest it could be: the conversation « Identifies a single
  # uniquely authenticated user » (chapter 4.4 §4.3.2), which nothing posted
  # before the authentication could claim to do. A click writes nothing further.
  def retour_connexion
    result = completed_identification

    return refuse_identification(result) unless result.success?

    session[:demo_journey] = opened_journey(result.identity).to_session
    session[:demo_identity] = result.identity.to_session

    redirect_to admin_demo_documents_path
  end

  # A page, where the other return is a redirection: FranceConnect+ brings back
  # here a user whose session has just ended on both sides, and there is nothing
  # left to send them on to.
  def retour_deconnexion
    expected = session.delete(:france_connect_logout)

    @acknowledged = expected.present? && params[:state] == expected
  end

  private

  def opened_journey(identity)
    Demo::Journey.opened(previous: Demo::Journey.from_session(session[:demo_journey]), subject: identity.subject)
  end

  def completed_identification
    Demo::CompleteIdentification.call(
      code: params[:code], state: params[:state], expected: session.delete(:france_connect),
      announced_error: params[:error], error_description: params[:error_description],
    )
  end
end
