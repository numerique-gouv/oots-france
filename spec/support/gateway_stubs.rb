# The Domibus double the specs of both message paths need.
#
# Its `submit` answers a `SubmittedMessageParser`, and not `nil`: the identifier
# the gateway gives the message it accepted is what the exchange log records,
# so a double that omits it fails where the code is right.
module GatewayStubs
  SUBMITTED_MESSAGE_ID = 'message-passerelle'.freeze

  def gateway_accepting_submissions(message_id: SUBMITTED_MESSAGE_ID, **answers)
    instance_double(DomibusClient, submit: instance_double(SubmittedMessageParser, message_id:), **answers)
  end
end
