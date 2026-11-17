module EvidenceProvision
  # The first request for « FR - Student status (MESRI) », as `ChooseAnswer`
  # answers it once nothing refuses it: the person is matched at API
  # Particulier on their pivot identity (chapter 2.1 §3.3) where the request
  # holds it whole, or sent to the preview space to be identified first, the
  # match then made on the identity FranceConnect+ certifies — chapter 4.9 §2,
  # step 3: re-authentication « may depend on the values of the eIDAS
  # attributes or the absence or presence of optional eIDAS attributes ».
  #
  # Nobody found is the empty list at once, whatever `PossibilityForPreview`
  # says — step 4, « use of the Preview Service is pointless » —; a failing
  # registry, the exception chapter 4.10 §3 names.
  module StudentStatusAnswers
    private

    def student_status_answer
      identity = PivotIdentity.from_request(request.beneficiary)
      return preview_required(lookup_pending: true) unless identity

      lookup = look_up(identity)
      return refusal(lookup.exception) if lookup.exception
      return empty_list if lookup.document.nil?

      found_student_status(lookup)
    end

    def look_up(identity)
      LookUpStudentStatus.call(identity:, distribution: served_distribution(request.evidence_type), clock:, uuid:,
        api_particulier: context.api_particulier)
    end

    # Assembled now, so that what the user previews is what the answer will
    # carry (chapter 4.9 §3).
    def found_student_status(lookup)
      return served_student_status(lookup) unless request.possibility_for_preview?

      preview_required(**lookup.to_h.slice(:evidence_id, :evidence_issued_at, :document))
    end

    def served_student_status(lookup)
      reference = OutgoingEnvelopeBuilder.payload_reference(uuid.next)
      body = evidence_body(beneficiary: request.beneficiary, evidence_type: request.evidence_type, reference:,
        evidence_id: lookup.evidence_id, clock: Oots::FrozenClock.new(lookup.evidence_issued_at))

      served_with(body, lookup.document)
    end
  end
end
