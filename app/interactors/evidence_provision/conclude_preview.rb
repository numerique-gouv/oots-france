module EvidenceProvision
  # Once the second request of a preview is answered, what France kept of the
  # user goes: chapter 4.9 asks for it until then, and nothing after.
  class ConcludePreview < ApplicationInteractor
    def call
      session = context.preview_session
      return if session.nil? || context.answer.withheld?

      session.conclude!
    end
  end
end
