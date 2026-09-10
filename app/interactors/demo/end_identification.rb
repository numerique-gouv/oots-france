module Demo
  # Ends the FranceConnect+ session that attested the identity, the other half
  # of `StartIdentification`: it draws the `state` the return will be checked
  # against, and builds the `/session/end` address the browser is sent to.
  #
  # It draws and does not store, for the reason its sibling gives: a session is
  # the controller's to touch.
  #
  # Failing here does not fail the sign-out. The operator is signed out either
  # way — `reset_session` has already run — and FranceConnect+ closes its own
  # session on inactivity; refusing to sign someone out because the portal is
  # unreachable would trade a session left open elsewhere for one left open
  # here.
  class EndIdentification < ApplicationInteractor
    def call
      state = SecureRandom.hex(StartIdentification::RANDOM_BYTES)

      context.end_session_url = client.end_session_url(id_token_hint: context.identity.id_token, state:)
      context.state = state
    rescue FranceConnectError, Faraday::Error => e
      Rails.logger.warn(I18n.t('interactors.demo.end_identification.unreachable', error: e.message))

      fail_with_error(:identification_refused, errors: [e.message])
    end

    private

    def client = context.client ||= FranceConnectClient.new
  end
end
