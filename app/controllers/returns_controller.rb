# The return address France puts in the second request of a preview (chapter
# 4.9 §5): the user, done in a correspondent's preview space, is sent back
# here and redirected on to the procedure. No page is rendered — a plain-text
# refusal at most, on an address unknown or expired: confirming that it is the
# right user and resuming the procedure are the portal's duties, the portal
# holding the session.
#
# `ActionController::API`: there is no page, so no layout, session or CSRF.
class ReturnsController < ActionController::API
  def show
    exchange = Exchange.find_by(return_token: params.expect(:token), incoming: false)

    return refuse(:unknown, :not_found) unless exchange&.preview_confirmed? && !exchange.pending?
    return refuse(:expired, :gone) unless exchange.return_open?

    returned = EvidenceRequest::ReturnToProcedure.call(exchange:, location: request.original_url)
    redirect_to returned.resume_address, allow_other_host: true, status: :see_other
  end

  private

  def refuse(key, status) = render(plain: I18n.t("returns.show.#{key}"), status:)
end
