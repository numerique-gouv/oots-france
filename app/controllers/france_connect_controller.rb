# The three addresses of the demonstration procedure FranceConnect+ is given,
# and the only part of this application it reads or sends a user to.
# `docs/eidas_context.md` says why they answer to a caller holding no session.
class FranceConnectController < ApplicationController
  # The « Client keys url » of the demonstration procedure. Distinct from the
  # key of `/auth/cles_publiques`, which opens the beneficiary token of a French
  # service provider — `Settings.france_connect_private_key_jwk` says why.
  def cles_publiques = render(json: PublicKeySet.new(Settings.france_connect_private_key_jwk).to_h)

  # Redirects rather than renders, whichever way it goes: an authorization code
  # is single use, and leaving in the history a page that carries one invites
  # replaying it.
  def retour_connexion
    result = completed_identification

    return refuse(result) unless result.success?

    session[:demo_identity] = result.identity.to_session

    redirect_to admin_demo_demande_path
  end

  # A page, where the other return is a redirection: FranceConnect+ brings back
  # here a user whose session has just ended on both sides, and there is nothing
  # left to send them on to.
  def retour_deconnexion
    expected = session.delete(:france_connect_logout)

    @acknowledged = expected.present? && params[:state] == expected
  end

  private

  def completed_identification
    Demo::CompleteIdentification.call(
      code: params[:code], state: params[:state], expected: session.delete(:france_connect),
      announced_error: params[:error], error_description: params[:error_description],
    )
  end

  def refuse(result)
    redirect_to admin_demo_root_path,
      flash: { alert: :"interactors.failures.#{result.error[:key]}", details: result.error[:errors] }
  end
end
