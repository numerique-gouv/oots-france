class JustificatifEducation {
  constructor(uuid) {
    this.uuid = uuid;
  }

  enXML() {
    return `<?xml version="1.0" encoding="UTF-8"?>
<query:QueryResponse xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
    xmlns:rs="urn:oasis:names:tc:ebxml-regrep:xsd:rs:4.0"
    xmlns:rim="urn:oasis:names:tc:ebxml-regrep:xsd:rim:4.0" xmlns:sdg="http://data.europa.eu/p4s"
    xmlns:query="urn:oasis:names:tc:ebxml-regrep:xsd:query:4.0"
    xmlns:xlink="http://www.w3.org/1999/xlink"
    status="urn:oasis:names:tc:ebxml-regrep:ResponseStatusType:Success"
    requestId="urn:uuid:${this.uuid}">
  <rim:Slot name="SpecificationIdentifier">
  </rim:Slot>
  <rim:Slot name="EvidenceResponseIdentifier">
  </rim:Slot>
  <rim:Slot name="IssueDateTime">
  </rim:Slot>
  <rim:Slot name="EvidenceProvider">
  </rim:Slot>
  <rim:Slot name="EvidenceRequester">
  </rim:Slot>
  <rim:RegistryObjectList>
  </rim:RegistryObjectList>
</query:QueryResponse>`;
  }
}

module.exports = JustificatifEducation;
