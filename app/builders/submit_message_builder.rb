# The envelope submitted to the `submitMessage` operation of the Domibus WS
# plugin: the ebMS header in the SOAP header, the RegRep message base64-encoded
# as a payload, and the evidence alongside it when there is one.
#
# No SOAP client, no MTOM, no WS-Security on our side: a `POST` in `text/xml`
# with basic authentication is all the plugin asks for, and it is how
# `apistration/siade` talks to Infogreffe and the ANTS.
class SubmitMessageBuilder < ApplicationBuilder
  attr_reader :payload_id, :attachment

  def initialize(body:, header:, payload_id:, attachment: EmptyAttachment.new)
    @body = body
    @header = header
    @payload_id = payload_id
    @attachment = attachment
  end

  protected

  def template_name = 'submit_message.xml.erb'

  private

  attr_reader :header

  # `strict_encode64` rather than `encode64`: the latter breaks the output into
  # 60-character lines, which is legal in MIME but pointless inside an XML
  # element.
  #
  # What goes between the `<value>` tags is the base64 and nothing else — no
  # surrounding punctuation. A MIME decoder skips characters outside the
  # alphabet, so a stray one travels unnoticed until a gateway rejects the
  # payload.
  def body_in_base64 = Base64.strict_encode64(@body)
end
