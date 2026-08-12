module EvidenceRequest
  # Asks which French service provider is behind the identifier the caller sent.
  #
  # A step, and not a lookup in the controller, because `EvidenceRequesterNotFound`
  # means two different things depending on where it is raised — a caller at
  # fault here, our own directory drifting on the incoming path — and the step
  # that knows which is which is the one that should say so.
  class ResolveRequester < ApplicationInteractor
    def call
      context.requester = context.requesters.find(context.requester_id)
    rescue EvidenceRequesterNotFound => e
      fail_with_error(:unknown_requester, errors: [e.message])
    end
  end
end
