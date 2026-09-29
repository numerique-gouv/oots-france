module EvidenceRequest
  # Picks the EDM version this request — and every message of the exchange after
  # it — is written in, from what the chosen access point declares, and the
  # version the caller asked for where it asked for one.
  #
  # Chapter 4.5.1 §2.2: « The SpecificationIdentifier must match with the
  # ConformsTo statement of the Access Service that has been chosen by the
  # Evidence Requester during the DSD Query Process ». The choice is made here
  # and not at the directory: the DSD query carries no `specification`
  # parameter, so its answer holds correspondents of both lines.
  #
  # A gateway declaring versions of which France speaks none is stopped here
  # rather than left to travel. No chapter says what such a gateway does with a
  # message it cannot read, and that is the reason to stop: nothing answers, and
  # the exchange reaches the expiry sweep of chapter 4.4, which writes it
  # `EDM:ERR:0005` — a correspondent's own timeout, imputed to one that may
  # never have been able to read us. Refusing here says whose fault it was while
  # it is still known.
  class ChooseSpecification < ApplicationInteractor
    def call
      recipient = context.recipient
      requested = context.requested_specification
      chosen = recipient.specification(requested)

      return refuse(recipient, requested) if chosen.nil? && requested
      return abandon(recipient) if chosen.nil?

      # On the exchange and nowhere else: it is what the worker handling the
      # answer reads back, long after this context has gone.
      context.exchange.update!(specification: chosen)
    end

    private

    # After `OpenExchange`, so the refusal is read back on the exchange the
    # console shows.
    def abandon(recipient)
      description = I18n.t('interactors.evidence_request.choose_specification.unsupported',
        access_point: recipient.id,
        announced: recipient.conforms_to.join(', '),
        spoken: EdmSpecification.identifiers.join(', '))

      fail_exchange(context.exchange, :unsupported_specification, description)
    end

    # The caller's doing rather than the correspondent's, hence a key of its
    # own: the contract answers it as the caller's to fix.
    def refuse(recipient, requested)
      description = I18n.t('interactors.evidence_request.choose_specification.unannounced',
        access_point: recipient.id,
        requested: requested.identifier,
        announced: recipient.conforms_to.join(', '))

      fail_exchange(context.exchange, :unannounced_specification, description)
    end
  end
end
