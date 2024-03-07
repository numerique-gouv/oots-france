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

    super(config, {
      ...donnees, pieceJointe,
    });
    this.idRequete = donnees.idRequete;
  }

  corpsMessageEnXML() {
    return `<query:QueryResponse
        xmlns:query="urn:oasis:names:tc:ebxml-regrep:xsd:query:4.0"
        xmlns:rim="urn:oasis:names:tc:ebxml-regrep:xsd:rim:4.0"
        xmlns:xlink="http://www.w3.org/1999/xlink"
        xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
        status="urn:oasis:names:tc:ebxml-regrep:ResponseStatusType:Success"
        requestId="urn:uuid:${this.idRequete}">

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

  <rim:Slot name="EvidenceProvider"><!-- … --></rim:Slot>
  <rim:Slot name="EvidenceRequester"><!-- … --></rim:Slot>

  <rim:RegistryObjectList>
    <rim:RegistryObject xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:type="rim:ExtrinsicObjectType" id="urn:uuid:0c37ed98-5774-407a-a056-21eeffe66712">
      <rim:Slot name="EvidenceMetadata">
        <sdg:Distribution>
          <sdg:Format>application/pdf</sdg:Format>
        </sdg:Distribution>
      </rim:Slot>
      <rim:RepositoryItemRef xlink:href="${this.pieceJointe.idPieceJointe}" xlink:title="Evidence"/>
    </rim:RegistryObject>
  </rim:RegistryObjectList>
</query:QueryResponse>
    `;
  }
}

module.exports = ReponseVerificationSysteme;
