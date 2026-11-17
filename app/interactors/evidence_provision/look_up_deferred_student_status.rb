module EvidenceProvision
  # The student status of a user, asked once they have identified on the
  # preview space and been recognised: chapter 4.9 §2, steps 16-17, « Now that
  # the user is successfully and uniquely authenticated, the list of pieces of
  # evidence for the user […] can be retrieved for preview ». The pivot
  # identity is the one FranceConnect+ has just certified, its sex and place of
  # birth included, and neither is kept nor logged.
  #
  # Once per address, under its lock: a revisit reads what was found. A
  # `gender` that says neither sex finds nobody, without asking.
  class LookUpDeferredStudentStatus < ApplicationInteractor
    def call
      session = context.preview_session
      waiting = session.with_lock { looked_up(session) if session.lookup_pending? && session.openable? }

      AnswerPreviewedRequestJob.perform_later(session.id) if waiting
    end

    private

    # Whether a held second request now waits on the registry's failure.
    def looked_up(session)
      identity = PivotIdentity.from_france_connect(context.identity)
      evidence_type = RetrievedMessageParser.new(session.first_request).body.evidence_type
      lookup = look_up(identity, evidence_type) if identity
      return session.unobtainable!(lookup.exception) if lookup&.exception

      found(session, lookup)
      false
    end

    # In the distribution the first request asked for: this call is the one
    # that fetches the attestation, where the PDF is what is served.
    def look_up(identity, evidence_type)
      LookUpStudentStatus.call(identity:, distribution: ServedEvidenceType.distribution_for(evidence_type), clock:,
        uuid:, api_particulier: context.api_particulier)
    end

    def found(session, lookup)
      return session.nothing_found! if lookup.nil? || lookup.document.nil?

      session.looked_up!(**lookup.to_h.slice(:document, :evidence_id, :evidence_issued_at))
    end
  end
end
