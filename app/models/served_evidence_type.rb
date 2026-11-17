# The evidence types France answers for as an Evidence Provider, among those it
# declares at the Evidence Broker of the acceptance environment: « FR - Student
# status (MESRI) » is served from API Particulier (`StudentStatus`); « FR -
# Test Evidence Type » and « FR - Test Evidence Type for abroad » are served
# with a test document (`EvidenceDocumentBuilder`); « FR - Test without
# evidence match (TC18) » is answered without one, no document matching any
# user (chapter 4.9 §1); « FR - Test Evidence Type not held » is declared
# without being served. The test types play the test cases of the Commission.
# A request is served on its evidence type, whatever procedure it names — `R1`
# aside, which is deferred whatever the type (`ProcedureCode.deferred?`): a
# provider holds evidence of a type, and `EDM:ERR:0004` — « Object not found »
# (chapter 4.5.3) — is what any other type gets.
#
# Compared on the country and the UUID that end the classification, the
# Semantic Repository publishing it under `sr.acc.oots.tech.ec.europa.eu` in
# acceptance and `sr.oots.tech.ec.europa.eu` in production.
module ServedEvidenceType
  UNMATCHED_CLASSIFICATION = 'FR/11cb64a4-6134-4b0e-aa6b-4a90250924ab'.freeze
  STUDENT_STATUS_CLASSIFICATION = 'FR/4daaf228-43fd-43fc-9148-a416c9a22464'.freeze

  CLASSIFICATIONS = [
    'FR/869a6748-bfc5-4de6-a0b4-ec0420f6b6a4',
    'FR/9bc466ca-d785-4b20-a5e2-0da1c0b9e931',
    UNMATCHED_CLASSIFICATION,
    STUDENT_STATUS_CLASSIFICATION,
  ].freeze

  def self.served?(evidence_type) = CLASSIFICATIONS.any? { |classification| classified?(evidence_type, classification) }

  def self.unmatched?(evidence_type) = classified?(evidence_type, UNMATCHED_CLASSIFICATION)

  def self.student_status?(evidence_type) = classified?(evidence_type, STUDENT_STATUS_CLASSIFICATION)

  # The distribution France serves for what the request asks, or none —
  # `EDM:ERR:0007`, chapter 4.5.1 §3.5: « only distributions which the data
  # service is able to provide can be requested ». The test types are served
  # in their test document's PDF alone.
  def self.distribution_for(evidence_type)
    return StudentStatus.distribution_for(evidence_type) if student_status?(evidence_type)

    ServedDistribution::PDF if evidence_type.requests?(EvidenceType::PDF)
  end

  def self.classified?(evidence_type, classification) = evidence_type.id.to_s.end_with?("/#{classification}")
  private_class_method :classified?
end
