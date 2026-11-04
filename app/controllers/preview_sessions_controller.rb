# France's preview space of chapter 4.9, reached by the user from the portal of
# another member state through the address France issued. No operator session:
# the unpredictable address finds the request, and the user identifies again
# through FranceConnect+ before anything of it is shown (§2, steps 15-17) —
# `PreviewIdentificationsController` receives them back.
class PreviewSessionsController < ApplicationController
  include ChosenLanguage
  include RecognisesPreviewIdentity

  # What of a correspondent's way back the session cookie carries through the
  # identification, in the bytes the cookie serialises it to: four kilobytes
  # once encrypted, for the whole departure and the verdicts beside it.
  RETURN_KEPT = 1024

  before_action :find_session

  def show
    return render(:show, status: :not_found) if @session.nil?

    EvidenceProvision::RecordPreviewVisit.call(preview_session: @session, location: request.original_url,
      return_url: params[:returnurl], return_method: params[:returnmethod], identified: confirmed?)
    return depart_to_identify if @preview.identification_required?

    leave_for_the_procedure if @preview.leaves_by_redirection?
  end

  def document
    return head(:not_found) unless confirmed? && @session.openable?

    send_data @session.document_bytes, type: Attachment::MIME_TYPE, disposition: :inline,
      filename: t('preview_sessions.document.filename')
  end

  # The zone that offers the way back, asked again while it waits for the
  # second request (chapter 4.9 §2, step 26). Not a visit: nothing is logged.
  def return_link
    return head(:not_found) unless @preview.offers_return?

    response.headers['Deferred-Fragment'] = '1'
    render partial: 'return', locals: { preview: @preview }
  end

  def decide
    return head(:not_found) unless confirmed?

    choice = params[:choice]
    return refuse_empty_choice unless choice.in?(PreviewSession::DECISIONS)

    EvidenceProvision::RecordPreviewDecision.call(preview_session: @session, decision: choice)
    return leave_for_the_procedure if @preview.leaves_by_redirection?

    redirect_to preview_session_path(token: @session.token), status: :see_other
  end

  private

  # Found by its token, and under the segment France issued it with: any other
  # is an address France never issued.
  def find_session
    @session = PreviewSession.issued(token: params[:token], version: params[:version])
    @preview = PreviewSessionPresenter.new(@session, first_request: read_first_request, verdict:)
  end

  def verdict = @session && preview_verdict(@session.token)

  def confirmed? = verdict == :confirmed

  # Emptied once nothing remains to answer, and read only while it is there.
  def read_first_request
    raw = @session&.first_request
    RetrievedMessageParser.new(raw).body if raw
  end

  # The FranceConnect+ the deployment declares for the space, with no choice
  # offered; the departure keeps what the return needs to find this address
  # again, and the way back a 1.2 visit brought (chapter 4.9 v1.2.3 §5).
  def depart_to_identify
    instance = Settings.preview_france_connect_instance
    return no_france_connect if instance.nil?

    result = Demo::StartIdentification.call(instance:, return_path: preview_franceconnect_retour_connexion_path)
    return identification_not_started(result) unless result.success?

    remember_departure(result, instance)
    redirect_to result.authorization_url, allow_other_host: true
  end

  def remember_departure(result, instance)
    session[:preview_identification] = {
      token: @session.token, version: params[:version], state: result.state, nonce: result.nonce,
      name: instance.name, returnurl: departing_return(params[:returnurl]),
      returnmethod: PreviewSession.return_method(params[:returnmethod])
    }
  end

  # A way back longer than the cookie can carry, or not even a string, is not
  # carried through the identification, and the page warns of it as of any way
  # back it could not keep (chapter 4.9 §2, step 13).
  def departing_return(value)
    value if value.is_a?(String) && ActiveSupport::JSON.encode(value).bytesize <= RETURN_KEPT
  end

  # Logged in error and not left to the interactor's warning: a space that
  # cannot start any identification is an outage of the deployment.
  def identification_not_started(result)
    Rails.logger.error(LogLine.t('controllers.preview_sessions.identification_not_started',
      reason: Array(result.error[:errors]).join(', ')))
    identification_unavailable(@session)
  end

  # `Settings::Contract` refuses to boot without a FranceConnect+ declared:
  # said in the log all the same, the page alone naming nothing an operator
  # could act on.
  def no_france_connect
    Rails.logger.error(LogLine.t('controllers.preview_sessions.no_france_connect'))
    identification_unavailable(@session)
  end

  # The address was vetted when it arrived — `WebAddress` on the 1.2 line,
  # R-EDM-REQ-C120 on the 2.0 one —, which is what allows another host.
  def leave_for_the_procedure
    redirect_to @session.return_location, allow_other_host: true, status: :see_other
  end

  def refuse_empty_choice
    @choice_missing = true
    render :show, status: :unprocessable_content
  end
end
