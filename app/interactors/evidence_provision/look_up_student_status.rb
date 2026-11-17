module EvidenceProvision
  # Asks API Particulier for the student status of the person a pivot identity
  # names, and assembles the evidence from what it returns: chapter 1 §5.2, « A
  # Data Service may respond to requests […] by creating or assembling
  # evidences from data dynamically ». The evidence is issued then, under a
  # fresh identifier (chapter 4.5.2 §3.3).
  #
  # Leaves `document` — the bytes to serve, in the `distribution` asked for —,
  # `evidence_id` and `evidence_issued_at` where the person was found, `exception` where the
  # registry failed (chapter 4.10 §3), and neither where nobody was found.
  class LookUpStudentStatus < ApplicationInteractor
    def call
      case api_particulier.student_status(context.identity, attestation: attestation?)
      in ApiParticulierClient::Found => found then assemble(found)
      in ApiParticulierClient::Unobtainable(exception) then context.exception = exception
      in ApiParticulierClient::NotFound then nil
      end
    end

    private

    def attestation? = context.distribution == StudentStatus::ATTESTATION

    def assemble(found)
      context.document = found.attestation || found.document
      context.evidence_id = uuid.next
      context.evidence_issued_at = clock.now
    end

    def api_particulier = context.api_particulier ||= ApiParticulierClient.new
  end
end
