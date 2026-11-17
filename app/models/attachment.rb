# A payload carried alongside the RegRep body — in practice, the evidence: the
# test PDF, or the student status in JSON or as its PDF attestation.
#
# `EmptyAttachment` stands for its absence, so the builders can interpolate it
# unconditionally instead of branching. `present?` is what distinguishes the
# two — never the class name, which a subclass would make wrong.
class Attachment
  MIME_TYPE = EvidenceType::PDF

  attr_reader :identifier, :content, :mime_type

  def initialize(identifier, content, mime_type: MIME_TYPE)
    @identifier = identifier
    @content = content
    @mime_type = mime_type
  end

  def present? = true
end
