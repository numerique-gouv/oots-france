module Demo
  # Opens the European flow of FranceConnect+: it draws what will tie the return
  # to this departure, and builds the `/authorize` address the browser is sent to.
  #
  # It draws and does not store: the two values belong to the session, and a
  # session is the controller's to touch.
  class StartIdentification < ApplicationInteractor
    # Sixteen bytes, so thirty-two hexadecimal characters. FranceConnect+
    # documents no minimum length for either parameter: this is what this
    # repository draws, and it is above what any implementation of the portal
    # has been seen to require.
    RANDOM_BYTES = 16

    def call
      state = SecureRandom.hex(RANDOM_BYTES)
      nonce = SecureRandom.hex(RANDOM_BYTES)

      context.authorization_url = client.authorization_url(state:, nonce:)
      context.state = state
      context.nonce = nonce
    rescue FranceConnectError, Faraday::Error => e
      reason = I18n.t('interactors.demo.start_identification.undiscoverable', error: e.message)
      Rails.logger.warn(reason)

      fail_with_error(:identification_refused, errors: [reason])
    end

    private

    def client = context.client ||= FranceConnectClient.new
  end
end
