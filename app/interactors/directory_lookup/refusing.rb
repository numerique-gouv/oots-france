module DirectoryLookup
  # A refusal is what this page came to show, so it travels with what the
  # directory answered — the message `CommonServicesResponseParser` composed,
  # and whether the refusal is the « nobody publishes this here » of chapters
  # 3.2.4 and 3.1.4 — rather than being translated into a named exception. The
  # steps already taken keep their results: the organizer hands back the context
  # as it stood, and a `DSD:ERR:0001` leaves the two Evidence Broker answers on
  # screen.
  #
  # The answer travels as data and not as a phrase: the presentation asks the
  # failure what the directory said, never the French wording composed from it.
  #
  # An outage is not a refusal and gets none of that: there is nothing worth
  # showing beside answers obtained from a service that then stopped answering.
  module Refusing
    private

    def refuse(error)
      raise error if error.outage?

      fail_with_error(:common_services_refused, errors: [error.message],
        nothing_published: error.nothing_published?)
    end
  end
end
