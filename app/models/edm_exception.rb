# The eight error codes of the TDD, copied column for column from the official
# code list published with them:
# https://code.europa.eu/oots/tdd/tdd_chapters/-/blob/2.0.1/OOTS-EDM/codelists/OOTS/EDMErrorCodes-CodeList.gc
#
# All eight are defined though three are emitted: the list is the
# specification's, not ours.
class EdmException
  include ActiveModel::Model
  include ActiveModel::Attributes

  ERROR = 'urn:oasis:names:tc:ebxml-regrep:ErrorSeverityType:Error'.freeze

  # OOTS-specific, and required by R-EDM-ERR-C022 whenever a `PreviewLocation`
  # slot accompanies the exception: an authorisation error that the user can
  # resolve by visiting the provider's preview space is not a failure of the
  # same kind as the others.
  PREVIEW_REQUIRED =
    'urn:sr.oots.tech.ec.europa.eu:codes:ErrorSeverity:EDMErrorResponse:PreviewRequired'.freeze

  attribute :type, :string
  attribute :message, :string
  attribute :severity, :string, default: ERROR
  attribute :code, :string

  AUTHENTICATION = new(
    type: 'rs:AuthenticationExceptionType',
    message: 'Failed Authentication',
    code: 'EDM:ERR:0001',
  ).freeze

  AUTHORIZATION = new(
    type: 'rs:AuthorizationExceptionType',
    message: 'Missing Authorization',
    severity: PREVIEW_REQUIRED,
    code: 'EDM:ERR:0002',
  ).freeze

  INVALID_REQUEST = new(
    type: 'rs:InvalidRequestExceptionType',
    message: 'Syntactically or semantically invalid request',
    code: 'EDM:ERR:0003',
  ).freeze

  OBJECT_NOT_FOUND = new(
    type: 'rs:ObjectNotFoundExceptionType',
    message: 'Object not found',
    code: 'EDM:ERR:0004',
  ).freeze

  TIMEOUT = new(
    type: 'rs:TimeoutExceptionType',
    message: 'Exceeding timeout period',
    code: 'EDM:ERR:0005',
  ).freeze

  UNRESOLVED_REFERENCE = new(
    type: 'rs:UnresolvedReferenceExceptionType',
    message: 'Referenced object that cannot be resolved',
    code: 'EDM:ERR:0006',
  ).freeze

  UNSUPPORTED_CAPABILITY = new(
    type: 'rs:UnsupportedCapabilityExceptionType',
    message: 'Optional feature or capability is not supported',
    code: 'EDM:ERR:0007',
  ).freeze

  QUERY = new(
    type: 'query:QueryExceptionType',
    message: 'Invalid query syntax or semantics that must be corrected',
    code: 'EDM:ERR:0008',
  ).freeze

  ALL = [
    AUTHENTICATION, AUTHORIZATION, INVALID_REQUEST, OBJECT_NOT_FOUND,
    TIMEOUT, UNRESOLVED_REFERENCE, UNSUPPORTED_CAPABILITY, QUERY,
  ].freeze

  def preview_required? = severity == PREVIEW_REQUIRED
end
