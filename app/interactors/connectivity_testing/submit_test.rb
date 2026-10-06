module ConnectivityTesting
  # Hands the gateway the test message of one pending connectivity test. A
  # submission the gateway refuses settles the test at once, with what the
  # gateway answered: nothing will ever come of it.
  class SubmitTest < ApplicationInteractor
    def call
      return unless test.pending? && test.message_id.nil?

      submitted(gateway.submit(envelope).message_id)
    rescue Faraday::Error => e
      log(e)
      refused(e)
    rescue UnreadableMessageError => e
      log(e)
      test.not_submitted!(e.message)
    end

    private

    def test = context.test

    def envelope = TestMessageBuilder.new(recipient: test.recipient).render

    # What the gateway answered: the code and the message of its fault, or its
    # words where it gives no code, or the error itself where it gave no fault.
    def refused(error)
      fault = SoapFaultParser.new(error.response&.dig(:body))
      return test.not_submitted!(code: fault.code, detail: fault.message) if fault.code

      test.not_submitted!(fault.reason || error.message)
    end

    def log(error)
      Rails.logger.warn(I18n.t('interactors.connectivity_testing.submit_test.refused',
        party: test.party_name, error: "#{error.class}: #{error.message}"))
    end

    def submitted(message_id)
      return test.submitted!(message_id) if message_id.present?

      test.not_submitted!(I18n.t('interactors.connectivity_testing.submit_test.no_identifier'))
    end
  end
end
