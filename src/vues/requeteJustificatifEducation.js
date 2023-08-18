class RequeteJustificatifEducation {
  constructor(uuid) {
    this.uuid = uuid;
  }

  enXML() {
    return `<?xml version="1.0" encoding="UTF-8"?>
<query:QueryRequest xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
  xmlns:rs="urn:oasis:names:tc:ebxml-regrep:xsd:rs:4.0" xmlns:sdg="http://data.europa.eu/p4s"
  xmlns:xmime="http://www.w3.org/2005/05/xmlmime"
  xmlns:rim="urn:oasis:names:tc:ebxml-regrep:xsd:rim:4.0"
  xmlns:query="urn:oasis:names:tc:ebxml-regrep:xsd:query:4.0"
  xmlns:xlink="http://www.w3.org/1999/xlink"
  xml:lang="DE"
  id="urn:uuid:${this.uuid}">
  <rim:Slot name="SpecificationIdentifier"/>
  <rim:Slot name="IssueDateTime"/>
  <rim:Slot name="Procedure"/>
  <rim:Slot name="PossibilityForPreview"/>
  <rim:Slot name="ExplicitRequestGiven"/>
  <rim:Slot name="Requirements"/>
  <rim:Slot name="EvidenceRequester"/>
  <rim:Slot name="EvidenceProvider"/>
  <query:ResponseOption returnType="LeafClassWithRepositoryItem"/>
  <query:Query queryDefinition="DocumentQuery">
    <rim:Slot name="EvidenceRequest"/>
    <rim:Slot name="NaturalPerson"/>
  </query:Query>
</query:QueryRequest>`;
  }
}

module.exports = RequeteJustificatifEducation;
