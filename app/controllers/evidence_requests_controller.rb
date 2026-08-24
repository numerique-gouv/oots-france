# The entry point a French service provider calls to ask for a piece of
# evidence held in another member state.
#
# The answer cannot come back on this connection: the gateway replies through a
# dispatcher running on its own schedule. So the caller receives the exchange
# identifier, which chapter 4.10 names as the way to tie a later reply to the
# request that caused it, and the evidence itself is delivered to the caller's
# own endpoint when it arrives.
#
# It receives the conversation identifier too. Chapter 4.4 lets the caller
# assign that one, to say that two requests are the same user's; one that does
# not needs the value back to lead its user through a second.
#
# Sending inline rather than from a job keeps the beneficiary token out of the
# queue, where it would be personal data written to disk.
class EvidenceRequestsController < ApplicationController
  # Neither the gateway nor the central directories are the caller's to fix,
  # and a 422 would blame them for an outage upstream.
  UPSTREAM_FAILURES = %i[gateway_refused common_services_refused invalid_directory_entry].freeze

  rescue_from EbmsError, with: :report_bad_request

  rescue_from ActiveRecord::RecordNotFound, with: :report_unknown_exchange

  before_action :check_feature_flag
  before_action :check_beneficiary, only: :create
  before_action :check_conversation_id, only: :create

  def create
    result = EvidenceRequest::Fetch.call(**fetch_arguments)

    return report_failure(result) unless result.success?

    render json: state_of(result.exchange), status: :accepted
  end

  def show
    render json: state_of(Exchange.find_by!(exchange_id: params.expect(:exchange_id)))
  end

  private

  # The EDM code travels with the state: a correspondent that refuses says why,
  # and that reason is the only thing the caller can act on.
  def state_of(exchange)
    {
      echange: exchange.exchange_id,
      conversation: exchange.conversation_id,
      statut: exchange.status,
      codeErreur: exchange.edm_error_code,
      adressePrevisualisation: exchange.preview_location,
    }.compact
  end

  # A query string and not a form: the caller is a server-side integration.
  def query
    @query ||= params.permit(:codeDemarche, :codePays, :idRequeteur, :beneficiaire,
      :previsualisationRequise, :idConversation)
  end

  # Upcased on the way in: both console filters upcase what they are asked, so
  # an `fr` stored as written would answer no search by country — on the very
  # log article 17 requires to be readable back.
  def country_code = query[:codePays]&.upcase

  def fetch_arguments
    {
      requester_id: query[:idRequeteur],
      conversation_id: query[:idConversation],
      requesters: Directories::EvidenceRequesters.new,
      encrypted_beneficiary: query[:beneficiaire],
      procedure_code: query[:codeDemarche],
      country_code:,
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

  # `R-EDM-ebMS-017` requires a UUID, and the rule is FATAL: a value of another
  # shape would travel in the header of every message of this exchange. Refused
  # here rather than on the way out, so that nothing is decrypted and no
  # directory is called for a request that cannot be sent.
  def check_conversation_id
    supplied = query[:idConversation]
    return if supplied.blank? || supplied.match?(Exchange::UUID)

    raison = t('evidence_requests.conversation_invalid')
    refuse(raison)

    render json: { erreur: raison }, status: :unprocessable_content
  end

  def report_unknown_exchange
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

    refuse(reason, exchange: result.exchange)

    render json: { erreur: reason }, status:
  end

  # Every refusal is journalled here rather than where it is raised: these never
  # reach the gateway, so nothing else holds a trace of them.
  def refuse(reason, exchange: nil)
    audit_trail.request_refused(
      requester_id: query[:idRequeteur],
      procedure_code: query[:codeDemarche],
      country_code:,
      reason:,
      exchange:,
    )
  end
end
