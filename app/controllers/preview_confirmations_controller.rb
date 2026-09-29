# The second call of the requester interface: the French service provider,
# having read on `GET /requete/:exchange_id` that a correspondent asks for a
# preview, confirms it — giving again the beneficiary token, which the exchange
# never kept, and the address of its own page where the user is to be brought
# back. France then emits the second request of chapter 4.9 §2 step 12 and
# answers with the link to present to the user, whose visit runs in parallel.
#
# `ActionController::API` and not `ApplicationController`: the caller is a
# server, with no session and no cookie, and therefore no CSRF protection to
# disable.
class PreviewConfirmationsController < ActionController::API
  FAILURE_STATUSES = EvidenceRequestsController::FAILURE_STATUSES.merge(preview_not_awaited: :conflict).freeze

  before_action :check_feature_flag
  before_action :find_exchange
  before_action :check_awaited
  before_action :check_beneficiary
  before_action :check_resume_location

  def create
    result = EvidenceRequest::ConfirmPreview.call(
      exchange: @exchange,
      requester_id: @exchange.evidence_requester_id,
      encrypted_beneficiary: confirmation[:beneficiaire],
      resume_location: confirmation[:adresseRetour],
      audit_trail:,
    )

    return report_failure(result) unless result.success?

    render json: ExchangeState.new(result.exchange, preview_link: result.preview_link).to_h, status: :accepted
  end

  private

  def confirmation = @confirmation ||= params.permit(:beneficiaire, :adresseRetour)

  def audit_trail = @audit_trail ||= AuditTrail.new

  def check_feature_flag
    return if Settings.evidence_request_enabled?

    render plain: 'Not Implemented Yet!', status: :not_implemented
  end

  # Only an exchange France asked for: one it answers has its own preview, and
  # nothing to confirm here.
  def find_exchange
    @exchange = Exchange.find_by(exchange_id: params[:exchange_id], incoming: false)
    return unless @exchange.nil?

    render json: { erreur: I18n.t('evidence_requests.unknown') }, status: :not_found
  end

  # Asked before the token is opened, and asked again under the lock of
  # `ConfirmExchange`, which alone settles two confirmations racing.
  def check_awaited
    refuse(:not_awaited, status: :conflict) unless @exchange.preview_required?
  end

  def check_beneficiary
    refuse(:beneficiary_required) if confirmation[:beneficiaire].blank?
  end

  # Where the user is brought back to must be somewhere a browser can go.
  def check_resume_location
    refuse(:resume_location_invalid) unless WebAddress.new(confirmation[:adresseRetour]).openable?
  end

  def refuse(key, status: :unprocessable_content)
    reason = I18n.t("preview_confirmations.create.#{key}")
    journal_refusal(reason)

    render json: { erreur: reason }, status:
  end

  def report_failure(result)
    error = result.error
    reason = error[:errors].join(' ; ')
    journal_refusal(reason)

    render json: { erreur: reason }, status: FAILURE_STATUSES.fetch(error[:key], :unprocessable_content)
  end

  # Journalled here for the reason `EvidenceRequestsController#refuse` gives:
  # no gateway log holds a confirmation that never led to a message.
  def journal_refusal(reason)
    audit_trail.request_refused(
      requester_id: @exchange.evidence_requester_id,
      procedure_code: @exchange.procedure_code,
      country_code: @exchange.country_code,
      reason:,
      exchange: @exchange,
    )
  end
end
