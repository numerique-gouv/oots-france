const expediteur = process.env.EXPEDITEUR_DOMIBUS;

const entete = (config = {}, donnees = {}) => {
  const { adaptateurUUID, horodateur } = config;

  const { destinataire, idConversation, idPayload } = donnees;
  const horodatage = horodateur.maintenant();
  const suffixe = process.env.SUFFIXE_IDENTIFIANTS_DOMIBUS;
  const idMessage = `${adaptateurUUID.genereUUID()}@${suffixe}`;
  const baliseIdConversation = (typeof idConversation !== 'undefined')
    ? `<eb:ConversationId>${idConversation}</eb:ConversationId>`
    : '';

  return `
<eb:Messaging xmlns:eb="http://docs.oasis-open.org/ebxml-msg/ebms/v3.0/ns/core/200704/"
  xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
  xsi:schemaLocation="http://docs.oasis-open.org/ebxml-msg/ebms/v3.0/ns/core/200704/
  https://www.oasis-open.org/committees/download.php/64179/ebms-header-3_0-200704_with_property_type_attribute.xsd">
  <eb:UserMessage>
    <eb:MessageInfo>
      <eb:Timestamp>${horodatage}</eb:Timestamp>
      <eb:MessageId>${idMessage}</eb:MessageId>
    </eb:MessageInfo>
    <eb:PartyInfo>
      <eb:From>
        <eb:PartyId type="urn:oasis:names:tc:ebcore:partyid-type:unregistered:oots-simulator">
          ${expediteur}
        </eb:PartyId>
        <eb:Role>http://sdg.europa.eu/edelivery/gateway</eb:Role>
      </eb:From>
      <eb:To>
        <eb:PartyId type="urn:oasis:names:tc:ebcore:partyid-type:unregistered:oots-simulator">
          ${destinataire}
        </eb:PartyId>
        <eb:Role>http://sdg.europa.eu/edelivery/gateway</eb:Role>
      </eb:To>
    </eb:PartyInfo>
    <eb:CollaborationInfo>
      <eb:Service type="urn:oasis:names:tc:ebcore:ebrs:ebms:binding:1.0">QueryManager</eb:Service>
      <eb:Action>ExecuteQueryRequest</eb:Action>
      ${baliseIdConversation}
    </eb:CollaborationInfo>
    <eb:MessageProperties>
      <eb:Property name="originalSender" type="urn:oasis:names:tc:ebcore:partyid-type:unregistered">C1</eb:Property>
      <eb:Property name="finalRecipient" type="urn:oasis:names:tc:ebcore:partyid-type:unregistered">C4</eb:Property>
    </eb:MessageProperties>
    <eb:PayloadInfo>
       <eb:PartInfo href="${idPayload}">
          <eb:PartProperties>
             <eb:Property name="MimeType">application/x-ebrs+xml</eb:Property>
          </eb:PartProperties>
       </eb:PartInfo>
    </eb:PayloadInfo>
  </eb:UserMessage>
</eb:Messaging>
  `;
};

module.exports = entete;
