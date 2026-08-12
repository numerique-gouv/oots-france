# A payload carried alongside the RegRep body — in practice, the evidence PDF.
#
# `EmptyAttachment` stands for its absence, so the builders can interpolate it
# unconditionally instead of branching. `present?` is what distinguishes the
# two — never the class name, which a subclass would make wrong.
class Attachment
  MIME_TYPE = 'application/pdf'.freeze

  attr_reader :identifier, :content

  def initialize(identifier, content)
    @identifier = identifier
    @content = content
  end

  def present? = true
end
