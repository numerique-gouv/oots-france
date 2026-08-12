# One outgoing message, ready for the gateway: the RegRep body, the ebMS header
# that describes it, and the evidence alongside when there is one.
#
# It exists for the payload reference: the header declares the payload and the
# submission carries it, so `cid:<document>@<suffix>` must be minted once and
# handed to both, or the header points at a payload that is not there.
#
# `header_attributes` are those of EbmsHeaderBuilder, minus the payload
# reference and the attachment, which this class owns.
class OutgoingEnvelopeBuilder
  # Also called on its own by the specimen generator, which writes header and
  # body to separate files and so has no envelope to build.
  def self.payload_reference(document_id) = "cid:#{document_id}@#{Settings.identifier_suffix}"

  def initialize(body:, attachment: EmptyAttachment.new, **header_attributes)
    @body = body
    @attachment = attachment
    @header_attributes = header_attributes
  end

  def render
    SubmitMessageBuilder.new(body: body.render, header:, payload_id:, attachment:).render
  end

  private

  attr_reader :body, :attachment, :header_attributes

  def payload_id = @payload_id ||= self.class.payload_reference(body.document_id)

  def header
    EbmsHeaderBuilder.new(**header_attributes, payload_id:, attachment:).render
  end
end
