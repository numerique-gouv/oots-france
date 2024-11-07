const fs = require('fs');

const EnteteReponse = require('./enteteReponse');
const Message = require('./message');
const PieceJointe = require('./pieceJointe');

class ReponseVerificationSysteme extends Message {
  static ClasseEntete = EnteteReponse;

  constructor(config, donnees) {
    const pieceJointe = new PieceJointe(
      `cid:${config.adaptateurUUID.genereUUID()}@pdf.oots.fr`,
      fs.readFileSync('./assets/drapeau.pdf').toString('base64'),
    );

    super(config, { ...donnees, pieceJointe });

    this.idRequete = donnees.idRequete;
    this.requeteur = donnees.requeteur;
  }

  corpsMessageEnXML() {
    return `<query:QueryResponse
        xmlns:query="urn:oasis:names:tc:ebxml-regrep:xsd:query:4.0"
        xmlns:rim="urn:oasis:names:tc:ebxml-regrep:xsd:rim:4.0"
        xmlns:sdg="http://data.europa.eu/p4s"
        xmlns:xlink="http://www.w3.org/1999/xlink"
        xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
        status="urn:oasis:names:tc:ebxml-regrep:ResponseStatusType:Success"
        requestId="${this.idRequete}">

  <rim:Slot name="SpecificationIdentifier">
    <rim:SlotValue xsi:type="rim:StringValueType">
      <rim:Value>oots-edm:v1.0</rim:Value>
    </rim:SlotValue>
  </rim:Slot>

  <rim:Slot name="EvidenceResponseIdentifier">
    <rim:SlotValue xsi:type="rim:StringValueType">
      <rim:Value>${this.adaptateurUUID?.genereUUID()}</rim:Value>
    </rim:SlotValue>
  </rim:Slot>

  <rim:Slot name="IssueDateTime">
    <rim:SlotValue xsi:type="rim:DateTimeValueType">
      <rim:Value>2023-03-10T10:20:31+02:00</rim:Value>
    </rim:SlotValue>
  </rim:Slot>

  <rim:Slot name="EvidenceProvider">
    <rim:SlotValue xsi:type="rim:CollectionValueType" collectionType="urn:oasis:names:tc:ebxml-regrep:CollectionType:Set">
      <rim:Element xsi:type="rim:AnyValueType">
        <sdg:Agent>
          <sdg:Identifier schemeID="urn:oasis:names:tc:ebcore:partyid-type:unregistered:FR"></sdg:Identifier>
          <sdg:Name></sdg:Name>
          <sdg:Classification>EP</sdg:Classification>
        </sdg:Agent>
      </rim:Element>
    </rim:SlotValue>
  </rim:Slot>

  ${this.requeteur.enXMLPourReponse()}

  <rim:RegistryObjectList>
    <rim:RegistryObject xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:type="rim:ExtrinsicObjectType" id="urn:uuid:0c37ed98-5774-407a-a056-21eeffe66712">
      <rim:Slot name="EvidenceMetadata">
        <rim:SlotValue xsi:type="rim:AnyValueType">
          <sdg:Evidence>
            <sdg:Identifier>${this.adaptateurUUID?.genereUUID()}</sdg:Identifier>
            <sdg:IsAbout>
              <sdg:NaturalPerson>
                <sdg:Identifier schemeID='eidas'>DK/DE/123123123</sdg:Identifier>
                <sdg:FamilyName></sdg:FamilyName>
                <sdg:GivenName></sdg:GivenName>
                <sdg:DateOfBirth>1970-03-01</sdg:DateOfBirth>
              </sdg:NaturalPerson>
            </sdg:IsAbout>
            <sdg:IssuingAuthority>
              <sdg:Identifier schemeID="urn:oasis:names:tc:ebcore:partyid-type:unregistered:FR"></sdg:Identifier>
              <sdg:Name></sdg:Name>
            </sdg:IssuingAuthority>
            <sdg:IsConformantTo>
              <sdg:EvidenceTypeClassification>
                https://sr.oots.tech.ec.europa.eu/evidencetypeclassifications/FR/12345678-1234-1234-1234-1234567890ab
              </sdg:EvidenceTypeClassification>
              <sdg:Title lang="EN"></sdg:Title>
            </sdg:IsConformantTo>
            <sdg:IssuingDate>1970-03-03</sdg:IssuingDate>
            <sdg:Distribution>
              <sdg:Format>application/pdf</sdg:Format>
            </sdg:Distribution>
          </sdg:Evidence>
        </rim:SlotValue>
      </rim:Slot>
      <rim:RepositoryItemRef xlink:href="${this.pieceJointe.identifiant}" xlink:title="Evidence"/>
    </rim:RegistryObject>
  </rim:RegistryObjectList>
</query:QueryResponse>
    `;
  }
}

module.exports = ReponseVerificationSysteme;
