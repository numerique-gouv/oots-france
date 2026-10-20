module Admin
  # Opens the Authorization Code Flow of the declared ProConnect: draws what
  # will tie the return to this departure, and builds the `/authorize` address
  # the browser is sent to. It draws and does not store: a session is the
  # controller's to touch.
  class StartProConnectSignIn < ApplicationInteractor
    # Sixteen bytes, so thirty-two hexadecimal characters: the minimum
    # ProConnect sets for both — « string (minimum 32 caractères) ».
    # https://partenaires.proconnect.gouv.fr/docs/fournisseur-service/implementation_technique
    RANDOM_BYTES = 16

    def call
      state = SecureRandom.hex(RANDOM_BYTES)
      nonce = SecureRandom.hex(RANDOM_BYTES)

      context.authorization_url = client.authorization_url(state:, nonce:)
      context.state = state
      context.nonce = nonce
    rescue ProConnectError, Faraday::Error => e
      fail_with_error(:sign_in_failed,
        errors: [I18n.t('interactors.admin.start_pro_connect_sign_in.undiscoverable', error: e.message)])
    end

    private

    def client = context.client ||= ProConnectClient.new(instance: context.instance)
  end
end
