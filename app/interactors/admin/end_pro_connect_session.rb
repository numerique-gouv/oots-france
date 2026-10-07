module Admin
  # Ends the agent's ProConnect session: draws the `state` the return will be
  # checked against, and builds the `/session/end` address the browser is sent
  # to, the ID Token as `id_token_hint`. It draws and does not store, for the
  # reason `StartProConnectSignIn` gives.
  class EndProConnectSession < ApplicationInteractor
    def call
      state = SecureRandom.hex(StartProConnectSignIn::RANDOM_BYTES)

      context.end_session_url = client.end_session_url(id_token_hint: context.id_token, state:)
      context.state = state
    rescue ProConnectError, Faraday::Error => e
      fail_with_error(:sign_in_failed,
        errors: [I18n.t('interactors.admin.end_pro_connect_session.unreachable', error: e.message)])
    end

    private

    def client = context.client ||= ProConnectClient.new(instance: context.instance)
  end
end
