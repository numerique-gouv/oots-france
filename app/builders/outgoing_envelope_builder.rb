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
    SubmitMessageBuilder.new(body: first_part.content, header:, payload_id:, attachment:).render
  end

  # The first MIME part as it goes on the wire, which chapter 4.8 has the log
  # keep whole. Memoised so that `render` embeds and the journal reads the very
  # same object, rather than two renderings that merely agree.
  def first_part
    @first_part ||= MimePart.new(mime_type: EbmsHeaderBuilder::REGREP_MIME_TYPE, content: body.render)
  end

  private

  attr_reader :body, :attachment, :header_attributes

  def payload_id = @payload_id ||= self.class.payload_reference(body.document_id)

  # Not memoised, and not idempotent: `EbmsHeaderBuilder` draws a message
  # identifier and a timestamp in its constructor, so each call describes a
  # different message. Rendering this envelope twice therefore submits two
  # messages the journal cannot both name — callers render it once.
  def header
    EbmsHeaderBuilder.new(**header_attributes, payload_id:, attachment:).render
  end
end
