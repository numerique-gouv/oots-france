# The end of the FranceConnect+ session that attested the demonstration
# identity, prepared for the two gestures that close it: the console's sign-out,
# which closes it with the operator's own, and the button of the identity card,
# which closes it alone.
#
# The session of the FranceConnect+ that attested this identity, and of no
# other: a deployment that no longer declares it has none of its own to end,
# and only the log says so.
#
# The state is written here rather than in the interactor, a session being the
# controller's to touch. `::Demo::` and not `Demo::`: the controllers including
# this live in `Admin`, where `Demo` names the controllers of the demonstration.
module EndsFranceConnectSession
  private

  # The address the browser is sent to, or `nil` when there is nothing to end or
  # it could not be prepared.
  def end_of_france_connect_session(identity)
    return nil if identity.nil?

    instance = Settings.france_connect_instance(identity.france_connect)
    return undeclared_france_connect(identity) if instance.nil?

    result = ::Demo::EndIdentification.call(identity:, instance:)
    return nil unless result.success?

    session[:france_connect_logout] = result.state

    result.end_session_url
  end

  def undeclared_france_connect(identity)
    Rails.logger.warn(LogLine.t('controllers.ends_france_connect_session.undeclared', name: identity.france_connect))

    nil
  end
end
