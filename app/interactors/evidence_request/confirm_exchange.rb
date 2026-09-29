module EvidenceRequest
  # Reopens the exchange a correspondent sent to a preview, under the return
  # address the second request will carry, and composes the link the portal
  # presents to the user.
  #
  # The address is a relay of this deployment rather than the portal's own, so
  # that the life cycle chapter 4.9 §5 gives it — « shall not be accessible before
  # the second request is issued », « for a time-limited period » — is kept here
  # once, and not by every portal. A random version 4 UUID makes it
  # « unpredictable », as §4 asks of the preview URL whose format it follows.
  class ConfirmExchange < ApplicationInteractor
    def call
      exchange = context.exchange

      confirmed = exchange.confirm_preview!(return_token: uuid.next, resume_location: context.resume_location)
      return fail_with_error(:preview_not_awaited, errors: [not_awaited]) unless confirmed

      addressed(exchange)
    end

    private

    def addressed(exchange)
      confirmed = context

      confirmed.preview_location = exchange.preview_location
      confirmed.return_location = exchange.return_location
      confirmed.preview_link = link(exchange)
    end

    def link(exchange)
      PreviewLink.new(location: exchange.preview_location, return_location: exchange.return_location,
        specification: exchange.specification, preview_method: exchange.preview_method)
    end

    def not_awaited = I18n.t('interactors.evidence_request.confirm_exchange.not_awaited')
  end
end
