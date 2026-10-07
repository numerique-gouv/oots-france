# What the login page and the two ProConnect returns share. The end of the
# agent's ProConnect session first, which both a sign-out and the refusal of an
# address outside the admitted domains go through: « Par défaut, ProConnect réutilisera une session existante », so a
# session left open would bring the same address back at the next click.
# https://partenaires.proconnect.gouv.fr/docs/fournisseur-service/implementation_technique
#
# Called **after** `reset_session`: what the return needs is all the fresh
# session holds — the `state`, the end of the FranceConnect+ session to chain
# on, the address the refusal names.
module ProConnectSession
  extend ActiveSupport::Concern

  private

  # The `/session/end` address, or `nil` when there is no ProConnect session to
  # end or ProConnect cannot be reached: the agent is signed out here either
  # way, and ProConnect closes its own session after twelve hours.
  def end_of_pro_connect_session(id_token, france_connect: nil, refused_email: nil)
    instance = Settings.proconnect_instance
    return nil if instance.nil? || id_token.blank?

    result = Admin::EndProConnectSession.call(instance:, id_token:)
    return log_unended(result) unless result.success?

    session[:pro_connect_logout] = { 'state' => result.state, 'france_connect' => france_connect,
                                     'refused_email' => refused_email }.compact
    result.end_session_url
  end

  # The ID Token the sign-out hands back as `id_token_hint`, kept in a cookie
  # of its own and not in the session: the cookie store bounds a cookie at four
  # kibibytes, and the session already carries the FranceConnect+ identity of
  # the demonstration — with both, a sign-in followed by an identification
  # measured 4058 bytes against the fake ProConnect, whose ID Token is smaller
  # than the real one's. Encrypted like the session, and as unreadable to a
  # script; `reset_session` does not reach it, so it is taken explicitly.
  # https://partenaires.proconnect.gouv.fr/docs/fournisseur-service/implementation_technique
  def keep_id_token(id_token)
    cookies.encrypted[:pro_connect_id_token] = { value: id_token, httponly: true, same_site: :lax }
  end

  def take_id_token = cookies.encrypted[:pro_connect_id_token].tap { cookies.delete(:pro_connect_id_token) }

  # What went wrong goes to the log, for the operator alone; the page says one
  # sentence for every cause.
  def pro_connect_failed(reasons)
    Rails.logger.warn(reasons.join(' '))

    redirect_to new_admin_session_path, alert: :'admin.sessions.pro_connect_failed'
  end

  def log_unended(result)
    Rails.logger.warn(result.error[:errors].join(' '))

    nil
  end
end
