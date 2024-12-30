const EnteteRequete = require('./enteteRequete');
const Fournisseur = require('./fournisseur');
const Message = require('./message');
const PersonnePhysique = require('./personnePhysique');
const Requeteur = require('./requeteur');
const TypeJustificatif = require('./typeJustificatif');

class RequeteJustificatif extends Message {
  static ClasseEntete = EnteteRequete;

  constructor(
    config,
    {
      beneficiaire = new PersonnePhysique(),
      codeDemarche = 'T1',
      destinataire = {},
      fournisseur = new Fournisseur(),
      idConversation = config.adaptateurUUID.genereUUID(),
      requeteur = new Requeteur(),
      typeJustificatif = new TypeJustificatif({}),
      previsualisationRequise = false,
    } = {},
  ) {
    super(config, { destinataire, idConversation });

    this.codeDemarche = codeDemarche;
    this.demandeur = beneficiaire;
    this.fournisseur = fournisseur;
    this.requeteur = requeteur;
    this.typeJustificatif = typeJustificatif;
    this.previsualisationRequise = previsualisationRequise;
  }

  corpsMessageEnXML() {
    const uuid = this.adaptateurUUID.genereUUID();
    const horodatage = this.horodateur.maintenant();

    return `<?xml version="1.0" encoding="UTF-8"?>
<query:QueryRequest xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
          xmlns:rs="urn:oasis:names:tc:ebxml-regrep:xsd:rs:4.0"
          xmlns:sdg="http://data.europa.eu/p4s"
          xmlns:xmime="http://www.w3.org/2005/05/xmlmime"
          xmlns:rim="urn:oasis:names:tc:ebxml-regrep:xsd:rim:4.0"
          xmlns:query="urn:oasis:names:tc:ebxml-regrep:xsd:query:4.0"
          xmlns:xlink="http://www.w3.org/1999/xlink"
          xmlns:xml="http://www.w3.org/XML/1998/namespace"
          xml:lang="EN"
          id="urn:uuid:${uuid}">

  <rim:Slot name="SpecificationIdentifier">
    <rim:SlotValue xsi:type="rim:StringValueType">
      <rim:Value>oots-edm:v1.0</rim:Value>
    </rim:SlotValue>
  </rim:Slot>
  <rim:Slot name="IssueDateTime">
    <rim:SlotValue xsi:type="rim:DateTimeValueType">
      <rim:Value>${horodatage}</rim:Value>
    </rim:SlotValue>
  </rim:Slot>
  <rim:Slot name="Procedure">
    <rim:SlotValue xsi:type="rim:InternationalStringValueType">
      <rim:Value>
        <rim:LocalizedString xml:lang="EN"
          value="${this.codeDemarche}"/>
      </rim:Value>
    </rim:SlotValue>
  </rim:Slot>
  <rim:Slot name="PossibilityForPreview">
    <rim:SlotValue xsi:type="rim:BooleanValueType">
      <rim:Value>${this.previsualisationRequise}</rim:Value>
    </rim:SlotValue>
  </rim:Slot>
  <rim:Slot name="ExplicitRequestGiven">
    <rim:SlotValue xsi:type="rim:BooleanValueType">
      <rim:Value>true</rim:Value>
    </rim:SlotValue>
  </rim:Slot>
  <rim:Slot name="Requirements">
    <rim:SlotValue xsi:type="rim:CollectionValueType"
      collectionType="urn:oasis:names:tc:ebxml-regrep:CollectionType:Set">
      <rim:Element xsi:type="rim:AnyValueType">
        <sdg:Requirement>
          <sdg:Identifier>https://sr.oots.tech.ec.europa.eu/requirements/f8a6a284-34e9-42c7-9733-63b5c4f4aa42</sdg:Identifier>
          <sdg:Name lang="EN">Proof of tertiary education diploma/certificate/degree</sdg:Name>
        </sdg:Requirement>
      </rim:Element>
    </rim:SlotValue>
  </rim:Slot>
  ${this.requeteur.enXMLPourRequete()}
  ${this.fournisseur.enXML()}
  <query:ResponseOption returnType="LeafClassWithRepositoryItem"/>
  <query:Query queryDefinition="DocumentQuery">
    ${this.demandeur.enXMLPourRequete()}
    ${this.typeJustificatif.enXML()}
  </query:Query>
</query:QueryRequest>`;
  }
}

module.exports = RequeteJustificatif;
