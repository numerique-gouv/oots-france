# The entry point a French service provider calls to ask for a piece of
# evidence held in another member state.
#
# The answer cannot come back on this connection: the gateway replies through a
# dispatcher running on its own schedule. So the caller receives the exchange
# identifier, which chapter 4.10 names as the way to tie a later reply to the
# request that caused it, and the evidence itself is delivered to the caller's
# own endpoint when it arrives.
#
# Sending inline rather than from a job keeps the beneficiary token out of the
# queue, where it would be personal data written to disk.
class EvidenceRequestsController < ApplicationController
  # Neither the gateway nor the central directories are the caller's to fix,
  # and a 422 would blame them for an outage upstream.
  UPSTREAM_FAILURES = %i[gateway_refused common_services_refused invalid_directory_entry].freeze

  rescue_from EbmsError, with: :report_bad_request

  rescue_from ActiveRecord::RecordNotFound, with: :report_unknown_conversation

  before_action :check_feature_flag
  before_action :check_beneficiary, only: :create

  def create
    result = EvidenceRequest::Fetch.call(**exchange)

    return report_failure(result) unless result.success?

    render json: state_of(result.conversation), status: :accepted
  end

  def show
    render json: state_of(Conversation.find_by!(conversation_id: params.expect(:conversation_id)))
  end

  private

  # The EDM code travels with the state: a correspondent that refuses says why,
  # and that reason is the only thing the caller can act on.
  def state_of(conversation)
    {
      conversation: conversation.conversation_id,
      statut: conversation.status,
      codeErreur: conversation.edm_error_code,
      adressePrevisualisation: conversation.preview_location,
    }.compact
  end

  # A query string and not a form: the caller is a server-side integration.
  def query
    @query ||= params.permit(:codeDemarche, :codePays, :idRequeteur, :beneficiaire, :previsualisationRequise)
  end

  def exchange
    {
      requester_id: query[:idRequeteur],
      requesters: Directories::EvidenceRequesters.new,
      encrypted_beneficiary: query[:beneficiaire],
      procedure_code: query[:codeDemarche],
      country_code: query[:codePays],
      preview_possible: preview_possible?,
      common_services: Directories::CommonServices.new,
      gateway: DomibusClient.new,
      uuid: UuidGenerator.new,
      audit_trail:,
    }
  end

  def audit_trail = @audit_trail ||= AuditTrail.new

  # A bare `previsualisationRequise` with no value counts as true, which is how
  # a flag appears in a query string.
  def preview_possible? = query[:previsualisationRequise].in?(['true', ''])

  def check_feature_flag
    return if Settings.evidence_request_enabled?

    render plain: 'Not Implemented Yet!', status: :not_implemented
  end

  def check_beneficiary
    return if query[:beneficiaire].present?

    raison = t('evidence_requests.beneficiary_required')
    refuse(raison)

    render json: { erreur: raison }, status: :unprocessable_content
  end

  def report_unknown_conversation
    render json: { erreur: t('evidence_requests.unknown') }, status: :not_found
  end

  def report_bad_request(error)
    refuse(error.message)

    render json: { erreur: error.message }, status: :unprocessable_content
  end

  def report_failure(result)
    error = result.error
    status = error[:key].in?(UPSTREAM_FAILURES) ? :bad_gateway : :unprocessable_content
    reason = error[:errors].join(' ; ')

    refuse(reason, conversation: result.conversation)

    render json: { erreur: reason }, status:
  end

  # Every refusal is journalled here rather than where it is raised: these never
  # reach the gateway, so nothing else holds a trace of them.
  def refuse(reason, conversation: nil)
    audit_trail.request_refused(
      requester_id: query[:idRequeteur],
      procedure_code: query[:codeDemarche],
      reason:,
      conversation:,
    )
  end
end
