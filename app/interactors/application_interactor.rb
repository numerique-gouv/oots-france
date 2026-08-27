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
                unknown_requester].freeze

  def fail_with_error(key, errors: [])
    context.fail!(error: { key:, errors: })
  end
end
