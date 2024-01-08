const EnteteRequete = require('./enteteRequete');
const Message = require('./message');

class RequeteJustificatif extends Message {
  static ClasseEntete = EnteteRequete;

  constructor(
    config,
    {
      codeDemarche = 'T1',
      destinataire = {},
      idConversation = config.adaptateurUUID.genereUUID(),
      previsualisationRequise = false,
    } = {},
  ) {
    super(config, { destinataire, idConversation });

    this.codeDemarche = codeDemarche;
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
  <rim:Slot name="EvidenceRequester">
    <rim:SlotValue xsi:type="rim:CollectionValueType">
      <rim:Element xsi:type="rim:AnyValueType">
        <sdg:Agent>
          <sdg:Identifier schemeID="urn:cef.eu:names:identifier:EAS:0096">DK22233223</sdg:Identifier>
          <sdg:Name lang="EN">Denmark University Portal</sdg:Name>
          <sdg:Address>
            <sdg:FullAddress>Prince Street 15, 1050 Copenhagen, Denmark</sdg:FullAddress>
            <sdg:LocatorDesignator>15</sdg:LocatorDesignator>
            <sdg:PostCode>1050</sdg:PostCode>
            <sdg:PostCityName>Copenhagen</sdg:PostCityName>
            <sdg:Thoroughfare>Prince Street</sdg:Thoroughfare>
            <sdg:AdminUnitLevel1>DK</sdg:AdminUnitLevel1>
            <sdg:AdminUnitLevel2>DK011</sdg:AdminUnitLevel2>
          </sdg:Address>
          <sdg:Classification>ER</sdg:Classification>
        </sdg:Agent>
      </rim:Element>
    </rim:SlotValue>
  </rim:Slot>
  <rim:Slot name="EvidenceProvider">
    <rim:SlotValue xsi:type="rim:AnyValueType">
      <sdg:Agent>
        <sdg:Identifier schemeID="urn:cef.eu:names:identifier:EAS:9930">BR_IT_01</sdg:Identifier>
        <sdg:Name lang="EN">Italy</sdg:Name>
      </sdg:Agent>
    </rim:SlotValue>
  </rim:Slot>
  <query:ResponseOption returnType="LeafClassWithRepositoryItem"/>
  <query:Query queryDefinition="DocumentQuery">
    <rim:Slot name="NaturalPerson">
      <rim:SlotValue xsi:type="rim:AnyValueType">
        <sdg:Person>
          <sdg:LevelOfAssurance>High</sdg:LevelOfAssurance>
          <sdg:Identifier schemeID="eidas">DK/DE/123123123</sdg:Identifier>
          <sdg:FamilyName>Smith</sdg:FamilyName>
          <sdg:GivenName>Jonas</sdg:GivenName>
          <sdg:DateOfBirth>1999-03-01</sdg:DateOfBirth>
          <sdg:BirthName>John Doepidis</sdg:BirthName>
          <sdg:PlaceOfBirth>Hamburg, Germany</sdg:PlaceOfBirth>
          <sdg:CurrentAddress>
            <sdg:FullAddress>Refshalevej 96, 1432 København, Denmark</sdg:FullAddress>
            <sdg:LocatorDesignator>96</sdg:LocatorDesignator>
            <sdg:PostCode>1432</sdg:PostCode>
            <sdg:PostCityName>København</sdg:PostCityName>
            <sdg:Thoroughfare>Refshalevej</sdg:Thoroughfare>
            <sdg:AdminUnitLevel1>DK</sdg:AdminUnitLevel1>
            <sdg:AdminUnitLevel2>DK011</sdg:AdminUnitLevel2>
          </sdg:CurrentAddress>
          <sdg:Gender>Male</sdg:Gender>
          <sdg:SectorSpecificAttribute>
            <sdg:AttributeName>IBAN</sdg:AttributeName>
            <sdg:AttributeURI>http://eidas.europa.eu/attributes/naturalperson/banking/IBAN</sdg:AttributeURI>
            <sdg:AttributeValue>DE02500105170137075032</sdg:AttributeValue>
          </sdg:SectorSpecificAttribute>
          <sdg:SectorSpecificAttribute>
            <sdg:AttributeName>BIC</sdg:AttributeName>
            <sdg:AttributeURI>http://eidas.europa.eu/attributes/naturalperson/banking/BIC</sdg:AttributeURI>
            <sdg:AttributeValue>INGDDEFFYYY</sdg:AttributeValue>
          </sdg:SectorSpecificAttribute>
        </sdg:Person>
      </rim:SlotValue>
    </rim:Slot>
    <rim:Slot name="EvidenceRequest">
      <rim:SlotValue xsi:type="rim:AnyValueType">
        <sdg:DataServiceEvidenceType xmlns="urn:oasis:names:tc:ebxml-regrep:xsd:rim:4.0">
          <sdg:Identifier>a8851d44-8f62-4561-99d2-5383ce3f30a7</sdg:Identifier>
          <sdg:EvidenceTypeClassification>https://sr.oots.tech.ec.europa.eu/evidencetypeclassifications/EU/b6a49e54-8b3c-4688-acad-380440dc5962</sdg:EvidenceTypeClassification>
          <sdg:Title lang="EN">Diploma</sdg:Title>
          <sdg:DistributedAs>
            <sdg:Format>application/xml</sdg:Format>
          </sdg:DistributedAs>
        </sdg:DataServiceEvidenceType>
      </rim:SlotValue>
    </rim:Slot>
  </query:Query>
</query:QueryRequest>`;
  }
}

module.exports = RequeteJustificatif;
