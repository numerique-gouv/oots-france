# France's preview space of chapter 4.9, reached by the user from the portal of
# another member state through the address France issued. No operator session:
# the unpredictable address is what opens it, which §1 admits until the space
# asks the user to authenticate again (OOTS-76).
class PreviewSessionsController < ApplicationController
  before_action :find_session

  def show
    return render(:show, status: :not_found) if @session.nil?

    EvidenceProvision::RecordPreviewVisit.call(preview_session: @session, location: request.original_url,
      return_url: params[:returnurl], return_method: params[:returnmethod])
  end

  def document
    return head(:not_found) unless @session&.openable?

    send_data @session.document_bytes, type: Attachment::MIME_TYPE, disposition: :inline,
      filename: t('preview_sessions.document.filename')
  end

  # The zone that offers the way back, asked again while it waits for the
  # second request (chapter 4.9 §2, step 26). Not a visit: nothing is logged.
  def return_link
    return head(:not_found) if @session.nil?

    response.headers['Deferred-Fragment'] = '1'
    render partial: 'return', locals: { preview: @preview }
  end

  def decide
    return head(:not_found) if @session.nil?

    choice = params[:choice]
    return refuse_empty_choice unless choice.in?(PreviewSession::DECISIONS)

    EvidenceProvision::RecordPreviewDecision.call(preview_session: @session, decision: choice)
    redirect_to preview_session_path(token: @session.token), status: :see_other
  end

  private

  # Found by its token, and under the segment France issued it with: any other
  # is an address France never issued.
  def find_session
    found = PreviewSession.find_by(token: params[:token])
    @session = found if found&.issued_under?(params[:version])
    @preview = PreviewSessionPresenter.new(@session, first_request: read_first_request)
  end

  # Emptied once nothing remains to answer, and read only while it is there.
  def read_first_request
    raw = @session&.first_request
    RetrievedMessageParser.new(raw).body if raw
  end

  def refuse_empty_choice
    @choice_missing = true
    render :show, status: :unprocessable_content
  end
end
