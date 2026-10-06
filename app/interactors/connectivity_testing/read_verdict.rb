module ConnectivityTesting
  # Reads, in the gateway, what became of the test message of one pending
  # connectivity test, and settles the test once there is a verdict. The
  # gateway notifies nothing about a test message, so this is the only way it
  # is known.
  #
  # A reading that fails changes nothing: the next sweep reads again, and
  # `ConnectivityTest::VERDICT_DEADLINE` closes what never answers.
  class ReadVerdict < ApplicationInteractor
    SENDING = 'SENDING'.freeze

    def call
      settle(gateway.message_status(test.message_id, role: SENDING))
    rescue Faraday::Error, UnreadableMessageError => e
      Rails.logger.error(I18n.t('interactors.connectivity_testing.read_verdict.unreadable',
        party: test.party_name, id: test.message_id, error: "#{e.class}: #{e.message}"))
    end

    private

    def test = context.test

    # Any other status is a message still on its way.
    def settle(status)
      if status.acknowledged? then test.acknowledged!
      elsif status.failed? then failed
      elsif status.not_found? then forgotten
      end
    end

    # A failure for which the gateway recorded no error stays one, without a
    # code (RG3 of OOTS-252), and the log keeps the message to look it up.
    def failed
      error = cause
      if error.nil?
        Rails.logger.warn(I18n.t('interactors.connectivity_testing.read_verdict.no_error',
          party: test.party_name, id: test.message_id))
      end
      test.failed!(error)
    end

    # Read without a role, and so under both: a refusal the correspondent
    # returns in a SOAP fault is recorded under `RECEIVING`, beside the
    # gateway's own `EBMS:0005` under `SENDING` (`MessageErrorsParser#cause`),
    # and a read naming `SENDING` would drop it (`ErrorLogEntry
    # .findErrorsByMessageIdAndRole`, Domibus `5.2-JEE10`). Only a test towards
    # France's own access point holds its identifier twice, which the form
    # without a role refuses; that one is read under `SENDING`.
    def cause
      gateway.message_errors(test.message_id).cause
    rescue Faraday::Error
      gateway.message_errors(test.message_id, role: SENDING).cause
    end

    # The gateway erases its test messages towards a party whenever its own
    # console tests that party (`TestService.deleteSentHistory`).
    def forgotten
      Rails.logger.warn(I18n.t('interactors.connectivity_testing.read_verdict.not_found',
        party: test.party_name, id: test.message_id))
      test.no_verdict!
    end
  end
end
