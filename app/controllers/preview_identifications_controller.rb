# Where FranceConnect+ brings back the user France's preview space sent to
# identify again (chapter 4.9 §2, steps 15-17), to the one address declared
# for it. It redirects to the space once the check is done, as the
# demonstration's return does: an authorization code is single use, and a
# page carrying one invites replaying it. Only a return no departure explains
# and an unreachable FranceConnect+ answer in place.
class PreviewIdentificationsController < ApplicationController
  include ChosenLanguage
  include RecognisesPreviewIdentity

  def retour_connexion
    departure = session[:preview_identification].to_h.symbolize_keys
    preview = PreviewSession.issued(token: departure[:token], version: departure[:version])
    return refuse_unknown_departure(departure[:token], :unknown_preview) if preview.nil?
    return refuse_unknown_departure(departure[:token], :another_state) unless tied_to?(departure)

    session.delete(:preview_identification)
    identified(preview, departure)
  end

  private

  def identified(preview, departure)
    identification = completed_identification(departure)
    return identification_unavailable(preview) if identification.unreachable

    check(preview, departure, identification)
    back_to_the_space(preview)
  end

  def back_to_the_space(preview)
    redirect_to preview_session_path(version: preview.specification.segment, token: preview.token), status: :see_other
  end

  # The `state` FranceConnect+ sends back with a code as with an error: a
  # return carrying another — a forged link, a second tab's departure — is
  # not this departure's, and must neither consume it nor conclude its
  # address.
  def tied_to?(departure)
    departure[:state].present? && ActiveSupport::SecurityUtils.secure_compare(departure[:state].to_s, params[:state].to_s)
  end

  def completed_identification(departure)
    Demo::CompleteIdentification.call(
      code: params[:code], state: params[:state], expected: departure,
      announced_error: params[:error], error_description: params[:error_description],
      return_path: preview_franceconnect_retour_connexion_path
    )
  end

  def check(preview, departure, identification)
    verdict = EvidenceProvision::CheckPreviewIdentity.call(preview_session: preview, identification:,
      return_url: departure[:returnurl], return_method: departure[:returnmethod]).verdict
    remember_preview_verdict(preview.token, verdict) if verdict
  end

  # A return no departure of this browser explains, or carrying another
  # `state`: nothing is consumed, and no preview is named. The log says which,
  # for a forged link and a second tab look alike to the user.
  # i18n-tasks-use t('controllers.preview_identifications.unknown_preview')
  # i18n-tasks-use t('controllers.preview_identifications.another_state')
  def refuse_unknown_departure(token, reason)
    Rails.logger.warn(LogLine.t("controllers.preview_identifications.#{reason}", token: token.presence || '-'))

    render plain: t('controllers.preview_identifications.unknown_departure'), status: :bad_request
  end
end
