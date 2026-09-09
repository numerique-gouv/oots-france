module Demo
  # Opens the European flow of FranceConnect+: it draws what will tie the return
  # to this departure, and builds the `/authorize` address the browser is sent to.
  #
  # It draws and does not store: the two values belong to the session, and a
  # session is the controller's to touch.
  class StartIdentification < ApplicationInteractor
    # Sixteen bytes, so thirty-two hexadecimal characters — the floor
    # FranceConnect+ documents for both parameters.
    # https://docs.partenaires.franceconnect.gouv.fr/fs/passerelle-eidas/technique-eidas-authorize/
    RANDOM_BYTES = 16

    def call
      state = SecureRandom.hex(RANDOM_BYTES)
      nonce = SecureRandom.hex(RANDOM_BYTES)

      context.authorization_url = client.authorization_url(state:, nonce:)
      context.state = state
      context.nonce = nonce
    rescue Faraday::Error, JSON::ParserError, KeyError => e
      undiscoverable(e)
    end

    private

    def undiscoverable(error)
      fail_with_error(:identification_refused,
        errors: [I18n.t('interactors.demo.start_identification.undiscoverable', error: error.message)])
    end

    def client = context.client ||= FranceConnectClient.new
  end
end
