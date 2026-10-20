# The envelope submitted to the `submitMessage` operation of the Domibus WS
# plugin for an eDelivery AS4 test message (chapter 4.7 §3.1): the service and
# the action of ebMS 3.0 Core §5.2.2.9, from France's access point to `recipient`.
#
# `originalSender` and `finalRecipient` are the ones the gateway gives its own
# test message (`messages/testservice/testservicemessage.json`, Domibus
# `5.2-JEE10`), untyped: the `fourCornersPropertySet` of the `testServiceCase`
# leg requires them. The payload and the conversation are those of
# `TestService.createSubmission`, same version, so that an access point that
# refuses a message without an attachment receives what the « Connection
# Monitoring » screen of the gateway's console sends it.
class TestMessageBuilder < ApplicationBuilder
  SERVICE = 'http://docs.oasis-open.org/ebxml-msg/ebms/v3.0/ns/core/200704/service'.freeze
  ACTION = 'http://docs.oasis-open.org/ebxml-msg/ebms/v3.0/ns/core/200704/test'.freeze
  ORIGINAL_SENDER = 'urn:oasis:names:tc:ebcore:partyid-type:unregistered:C1'.freeze
  FINAL_RECIPIENT = 'urn:oasis:names:tc:ebcore:partyid-type:unregistered:C4'.freeze
  CONVERSATION_ID = '1'.freeze
  PAYLOAD_ID = 'cid:message'.freeze
  PAYLOAD_MIME_TYPE = 'text/xml'.freeze
  PAYLOAD = '<?xml version="1.0" encoding="UTF-8"?><hello>world</hello>'.freeze

  attr_reader :sender, :recipient

  def initialize(recipient:, sender: AccessPoint.sender)
    @recipient = recipient.validate!(:recipient_access_point)
    @sender = sender
  end

  def payload_in_base64 = Base64.strict_encode64(PAYLOAD)

  protected

  def template_name = 'submit_test_message.xml.erb'
end
