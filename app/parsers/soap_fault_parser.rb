# A SOAP 1.2 fault of the Domibus WS plugin. A submission it refuses carries a
# `FaultDetail` (`webservicePlugin-body.xsd`): the ebMS code of the refusal,
# written `EBMS:0003` (`WebServiceImpl.generateFaultDetail`, Domibus
# `5.2-JEE10`), or one of the plugin's own, `WS_PLUGIN_0005`, and a message. The
# children of `FaultDetail` carry no namespace, the schema being
# `elementFormDefault="unqualified"`.
class SoapFaultParser
  include OotsNamespaces

  FAULT = '//soap:Body/soap:Fault'.freeze
  DETAIL = "#{FAULT}/soap:Detail/ws:FaultDetail".freeze

  def initialize(xml)
    @document = Nokogiri::XML(xml.to_s)
  end

  # In the norm's form when it is an ebMS code, as `DeliveryError` writes it;
  # the plugin's own as it comes.
  def code
    code = text_at(document, "#{DETAIL}/code").presence
    code&.start_with?('EBMS') ? DeliveryError.new(code:).code : code
  end

  def message = text_at(document, "#{DETAIL}/message").presence

  # What the fault says where it carries no code.
  def reason = message || text_at(document, "#{FAULT}/soap:Reason/soap:Text").presence

  private

  attr_reader :document
end
