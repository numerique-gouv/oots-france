module DirectoryLookup
  # A refusal is what this page came to show, so it travels with the code the
  # directory named — `CommonServicesResponseParser` puts it at the head of the
  # message — rather than being translated into a named exception. The steps
  # already taken keep their results: the organizer hands back the context as it
  # stood, and a `DSD:ERR:0001` leaves the two Evidence Broker answers on screen.
  #
  # An outage is not a refusal and gets none of that. `code` is what tells them
  # apart — an invalid signature, an unresolvable NAPTR record, an unreachable
  # directory carry none — and there is nothing worth showing beside answers
  # obtained from a service that then stopped answering.
  module Refusing
    private

    def refuse(error)
      raise error if error.code.blank?

      fail_with_error(:common_services_refused, errors: [error.message])
    end
  end
end
