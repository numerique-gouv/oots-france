# One step of an exchange.
#
# `fail_with_error` follows the convention of the team's other applications: a
# failure is structured, never a bare string. The key carries the EDM code when
# there is one, because these failures are not flow control — they become
# `rs:Exception` elements in a response, or an HTTP status handed back to the
# French service provider.
class ApplicationInteractor
  include Interactor

  def fail_with_error(key, errors: [])
    context.fail!(error: { key:, errors: })
  end
end
