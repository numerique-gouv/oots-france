module EvidenceProvision
  # The user back from identifying again in France's preview space, and the
  # identity swap check of chapter 4.9 §2, step 18 (`IdentityMatch`).
  #
  # Every outcome is journalled (article 17(1) of implementing regulation
  # 2022/1463), and `verdict` says what this browser may now see. A failure —
  # an identification that did not complete, or one of someone else —
  # concludes an address still open: steps 19-20 have the user « not get access
  # to any evidences », and the second request answered `EDM:ERR:0001`.
  #
  # No verdict at all where nothing could be checked: the subject already
  # erased, the answer gone.
  class CheckPreviewIdentity < ApplicationInteractor
    def call
      session = context.preview_session
      return if session.first_request.nil?

      outcome = outcome_of(context.identification, session)
      audit_trail.preview_identified(session:, outcome:)
      outcome == PreviewSession::CONFIRMED ? confirmed(session) : failed(session, outcome)
    end

    private

    def outcome_of(identification, session)
      return PreviewSession::UNAUTHENTICATED unless identification.success?
      return PreviewSession::MISMATCHED unless same_person?(identification.identity, session)

      PreviewSession::CONFIRMED
    end

    def same_person?(identity, session)
      IdentityMatch.new(identity, RetrievedMessageParser.new(session.first_request).body.beneficiary).match?
    end

    def confirmed(session)
      context.verdict = :confirmed
      remember_return(session)
    end

    # On the 1.2 line the way back the failing visit brought is kept only
    # where none is yet, and offered to that browser alone: a refused user is
    # sent back by it (steps 15-17), but neither replaces nor reads the way
    # back of someone else. On 2.0 the way back is the portal's, from the
    # second request, and goes to whoever's failure concluded the address.
    def failed(session, outcome)
      own_return = false
      waiting = session.fail_identification!(outcome) do |locked|
        own_return = !locked.specification.preview_method_slot? || locked.return_location.blank?
        remember_return(locked) if own_return
      end

      context.verdict = own_return ? :refused : :rejected
      AnswerPreviewedRequestJob.perform_later(session.id) if waiting
    end

    def remember_return(session)
      RememberPreviewReturn.call(preview_session: session, return_url: context.return_url,
        return_method: context.return_method)
    end
  end
end
