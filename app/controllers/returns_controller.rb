# The return address France puts in the second request of a preview (chapter
# 4.9 §5): the user, done in a correspondent's preview space, is sent back
# here, and redirected on to the page of the procedure the portal named when it
# confirmed. Nothing is rendered to them — confirming that it is the right user
# and resuming the procedure are the portal's duties, the portal holding the
# session.
#
# The two identifiers of the exchange ride along, in the words `POST
# /oots/document` already uses: chapter 1 §7.9 has the link back « include all
# data elements required for enabling logging for end-to-end correlation ».
#
# `ActionController::API`: there is no page, so no layout, session or CSRF.
class ReturnsController < ActionController::API
  def show
    exchange = Exchange.find_by(return_token: params.expect(:token), incoming: false)

    return refuse(:unknown, :not_found) unless exchange&.preview_confirmed? && !exchange.pending?
    return refuse(:expired, :gone) unless exchange.return_open?

    AuditTrail.new.return_visited(exchange:, location: request.original_url)
    redirect_to resume_address(exchange), allow_other_host: true, status: :see_other
  end

  private

  # Appended to whatever query the portal's address already carries, rather
  # than concatenated onto it.
  def resume_address(exchange)
    address = URI.parse(exchange.resume_location)
    carried = URI.decode_www_form(address.query.to_s)
    address.query = URI.encode_www_form(
      [*carried, ['echange', exchange.exchange_id], ['conversation', exchange.conversation_id]],
    )

    address.to_s
  end

  def refuse(key, status) = render(plain: I18n.t("returns.show.#{key}"), status:)
end
