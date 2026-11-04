# What France's preview space remembers of the browser in front of it: the
# identity check it passed or failed, address by address. Chapter 4.9 §2,
# steps 15-17, has the space « recognize repeat visits of a user » by a
# cookie; this is that cookie, the session one, and it holds no attribute of
# the person — only the outcome.
#
# One verdict per address and no further: a check passed for one request does
# not open another, even of the same user (a document per request).
module RecognisesPreviewIdentity
  # The session is a cookie of four kilobytes: the oldest verdicts give way.
  KEPT = 5

  # `refused` where this browser's failure concluded the address and no way
  # back was yet kept for it; `rejected` where a way back, or the conclusion,
  # was already someone else's — refused all the same, and offered nothing.
  VERDICTS = %i[confirmed refused rejected].freeze

  private

  def preview_verdict(token)
    session[:preview_verdicts].to_h[token.to_s]&.to_sym&.presence_in(VERDICTS)
  end

  def remember_preview_verdict(token, verdict)
    kept = session[:preview_verdicts].to_h.except(token.to_s)

    session[:preview_verdicts] = kept.to_a.last(KEPT - 1).to_h.merge(token.to_s => verdict.to_s)
  end

  # FranceConnect+ could not be reached: nothing of the request is shown, and
  # the address stays open.
  def identification_unavailable(preview_session)
    @preview = PreviewSessionPresenter.new(preview_session, unavailable: true)
    render 'preview_sessions/show', status: :service_unavailable
  end
end
