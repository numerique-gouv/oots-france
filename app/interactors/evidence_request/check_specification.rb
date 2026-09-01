module EvidenceRequest
  # Confronts the EDM versions the chosen access point declares to the one the
  # request is about to carry.
  #
  # This is not a negotiation: chapter 3.1.4 puts that at the directory, through
  # the `specification` parameter `DataServiceDirectoryClient` already sends,
  # and this deployment produces one version only. It is a coherence check on
  # the directory's own answer — `sdg:ConformsTo` being « the registered
  # version(s) […] used by the access service » and the very element that
  # parameter filters on, an access service returned under the filter yet
  # declaring other versions is a directory contradicting itself.
  #
  # No chapter says what such a gateway does with the message, and that is the
  # reason to stop rather than to proceed: nothing answers, and the exchange
  # reaches the expiry sweep of chapter 4.4, which writes it `EDM:ERR:0005` —
  # a correspondent's own timeout, imputed to one that may never have been
  # able to read us. Refusing here says whose fault it was while it is still
  # known.
  class CheckSpecification < ApplicationInteractor
    def call
      recipient = context.recipient
      return if recipient.speaks?(EdmSpecification::IDENTIFIER)

      abandon(recipient)
    end

    private

    # After `OpenExchange`, so the refusal is read back on the exchange the
    # console shows.
    def abandon(recipient)
      description = I18n.t('interactors.evidence_request.check_specification.unsupported',
        access_point: recipient.id,
        announced: recipient.conforms_to.join(', '),
        expected: EdmSpecification::IDENTIFIER)

      fail_exchange(context.exchange, :unsupported_specification, description)
    end
  end
end
