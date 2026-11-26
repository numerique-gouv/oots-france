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

  # The cause `soumissionRefusee.xml` carries, a submission towards a party the
  # PMode does not declare, read by the real client over HTTP: what is in
  # question is the cause the client draws from the fault, which a double
  # raising an error of its own would skip.
  REFUSAL_CAUSE = ['EBMS:0003', 'Receiver party could not be found for the value'].freeze

  def refusal_cause = REFUSAL_CAUSE

  def refuse_submissions(gateway)
    allow(Settings).to receive_messages(domibus_base_url: 'http://domibus:8080/domibus',
      domibus_credentials: { login: 'oots', password: 'secret' })
    stub_request(:post, 'http://domibus:8080/domibus/services/wsplugin/submitMessage')
      .to_return(status: 500, body: read_fixture('incoming/domibus/soumissionRefusee.xml'))
    client = DomibusClient.new(connection: DomibusClient.connection)
    allow(gateway).to receive(:submit) { |envelope| client.submit(envelope) }
  end

  # The error the real client raises on that refusal, for a spec that stubs
  # what reads it.
  def submission_refusal
    gateway = instance_double(DomibusClient)
    refuse_submissions(gateway)
    gateway.submit('<soap:Envelope/>')
  rescue SubmissionRefused => e
    e
  end
end
