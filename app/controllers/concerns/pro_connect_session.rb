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
