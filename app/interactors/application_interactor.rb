# One step of an exchange.
#
# `fail_with_error` follows the convention of the team's other applications: a
# failure is structured, never a bare string. The key carries the EDM code when
# there is one, because these failures are not flow control — they become
# `rs:Exception` elements in a response, or an HTTP status handed back to the
# French service provider.
class ApplicationInteractor
  include Interactor

  # The failures this application knows how to say. A `fail_with_error` on a key
  # absent from here has no wording, and the console would render an empty
  # alert title.
  FAILURES = %i[common_services_refused gateway_refused invalid_configuration invalid_directory_entry
                invalid_token no_evidence_type no_provider unknown_country unknown_procedure
                unknown_requester unsupported_specification].freeze

  def fail_with_error(key, errors: [])
    context.fail!(error: { key:, errors: })
  end

  # A refusal pronounced before anything is submitted: the exchange carries the
  # reason, and the caller gets it back as a structured failure.
  #
  # No EDM code, ever: the eight exceptions of chapter 4.5.3 are all generated
  # by a server handling a client's request, and none names a sender whose own
  # submission never left. The description is then the only thing that says to
  # whom the failure belongs.
  #
  # Named neither `abandon` nor `abandon_exchange`: `IncomingMessage::Process`
  # already carries the second, and means something else by it — it settles an
  # exchange it has to find, and lets the interactor succeed.
  def fail_exchange(exchange, key, description)
    exchange.failed!(code: nil, description:)
    fail_with_error(key, errors: [description])
  end
end
