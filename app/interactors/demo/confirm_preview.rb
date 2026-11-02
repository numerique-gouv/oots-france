module Demo
  # What the demonstration procedure does the first time it reads that the
  # correspondent asks for a preview: confirm it, and keep the link France
  # answers with.
  #
  # Chapter 4.9 §5 lists the portal's duties: « Recognize, in the first flow,
  # evidence error response messages of type rs:AuthorizationExceptionType that
  # contain a "PreviewLocation" slot », then « Provide a departure page for the
  # user to navigate to the Preview Space ». The contract gives the link only in
  # its answer to the confirmation, and a second confirmation receives `409`, so
  # the link is kept on the request and a confirmation that succeeded is never
  # repeated. A failure keeps nothing: the zone stops asking and says so, and
  # only a reload of the page tries again.
  #
  # Under the row's lock: the page and the zone may read the state in the same
  # instant, and the one that loses would otherwise confirm again and be told
  # `409` for a preview that is under way.
  #
  # The beneficiary token is sealed at this instant from the identity the
  # session holds, like the one the click sent: the exchange never kept it.
  #
  # Every variant of the description is kept with the link: only the state
  # awaiting the confirmation carries them, and the departure page chooses one
  # at each display, in the language the reader chose then — chapter 4.9 §5,
  # « to allow the launch page to be customized to the user's language choice
  # (if known) ».
  class ConfirmPreview < ApplicationInteractor
    def call
      request = context.request

      request.with_lock do
        next if request.preview_link?

        answer = confirm(request)
        next refuse(answer) unless answer.confirmed?

        keep(request, answer)
      end
    rescue DemoContractError, Faraday::Error, UnusableKeySetError => e
      unconfirmed(e.message)
    end

    private

    def confirm(request)
      client.confirm(exchange_id: request.exchange_id,
        encrypted_beneficiary: token_writer.call(context.identity), resume_location: context.resume_location,
        provider_classifications: request.provider_classifications)
    end

    def keep(request, answer)
      request.update!(
        preview_address: answer.preview_location, preview_method: answer.preview_method,
        preview_body: answer.preview_body, preview_descriptions:,
      )
    end

    # In the shape `Exchange#preview_descriptions` has, rather than the
    # contract's French field names.
    def preview_descriptions
      context.state.preview_descriptions.map do |described|
        { 'language' => described['langue'], 'text' => described['texte'] }
      end
    end

    # The message the contract returned is the only thing that says why: the
    # exchange no longer awaited a confirmation, the return address was refused.
    def refuse(answer) = unconfirmed(answer.error.presence || answer.status.to_s)

    # Logged as much as shown, like the other interactors of `Demo::`: the zone
    # says it, and the log is what remains once the screen is closed.
    def unconfirmed(reason)
      Rails.logger.warn(LogLine.t('interactors.demo.confirm_preview.unconfirmed',
        exchange: context.request.exchange_id, error: reason))

      fail_with_error(:demo_preview_unconfirmed, errors: [reason])
    end

    def client = context.confirmation_client ||= PreviewConfirmationClient.new

    def token_writer = context.token_writer ||= BeneficiaryTokenWriter.new
  end
end
