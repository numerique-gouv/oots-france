# What France's preview space remembers of the browser in front of it: the
# departure to FranceConnect+ — the address, the `state` and `nonce` its return
# is checked against, a 1.2 visit's way back — and the identity check each
# address passed or failed. Chapter 4.9 §2, steps 15-17, has the space
# « recognize repeat visits of a user » by a cookie; the verdicts are that
# cookie, and hold no attribute of the person — only the outcome.
#
# Two encrypted cookies of their own and not the session: the cookie store
# writes the whole session back with every response that read it, so a request
# answered after the departure or the return — the zone of the demonstration
# procedure asking for its state, another address's zone of return — would put
# back the session from before, and with it lose the departure or the verdict.
# Only the actions of the space that change them write these two.
#
# One verdict per address and no further: a check passed for one request does
# not open another, even of the same user (a document per request).
module RecognisesPreviewIdentity
  COOKIES = %i[preview_identification preview_verdicts].freeze

  # The `Cookie` header that carries them back with the others must fit the
  # eight kibibytes a front leaves it by default: the oldest verdicts give way.
  KEPT = 5

  # `refused` where this browser's failure concluded the address and no way
  # back was yet kept for it; `rejected` where a way back, or the conclusion,
  # was already someone else's — refused all the same, and offered nothing.
  VERDICTS = %i[confirmed refused rejected].freeze

  private

  def preview_departure = cookies.encrypted[:preview_identification].to_h.symbolize_keys

  def keep_preview_departure(departure) = keep_encrypted(:preview_identification, departure)

  def spend_preview_departure = cookies.delete(:preview_identification)

  def preview_verdict(token)
    preview_verdicts[token.to_s]&.to_sym&.presence_in(VERDICTS)
  end

  def remember_preview_verdict(token, verdict)
    kept = preview_verdicts.except(token.to_s)

    keep_encrypted(:preview_verdicts, kept.to_a.last(KEPT - 1).to_h.merge(token.to_s => verdict.to_s))
  end

  def preview_verdicts = cookies.encrypted[:preview_verdicts].to_h

  # FranceConnect+ could not be reached: nothing of the request is shown, and
  # the address stays open.
  def identification_unavailable(preview_session)
    @preview = PreviewSessionPresenter.new(preview_session, unavailable: true)
    render 'preview_sessions/show', status: :service_unavailable
  end
end
