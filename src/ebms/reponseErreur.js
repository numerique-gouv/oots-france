const DESCRIPTIONS_EXCEPTIONS = {
  QUERY_EXCEPTION: {
    type: 'query:QueryExceptionType',
    message: 'Query Exception',
    severite: 'urn:oasis:names:tc:ebxml-regrep:ErrorSeverityType:Error',
    code: 'EDM:ERR:0008',
  },
  OBJECT_NOT_FOUND_EXCEPTION: {
    type: 'rs:ObjectNotFoundExceptionType',
    message: 'Object not found',
    severite: 'urn:oasis:names:tc:ebxml-regrep:ErrorSeverityType:Error',
    code: 'EDM:ERR:0004',
  },
};

class ReponseErreur {
  constructor(donnees = {}, config = {}) {
    this.idRequete = donnees.idRequete;
    this.typeException = donnees.exception?.type;
    this.messageException = donnees.exception?.message;
    this.severiteException = donnees.exception?.severite;
    this.codeException = donnees.exception?.code;

    this.horodateur = config.horodateur;
    this.adaptateurUUID = config.adaptateurUUID;
  }

  enXML() {
    return `<?xml version="1.0" encoding="UTF-8"?>
<query:QueryResponse xmlns:rim="urn:oasis:names:tc:ebxml-regrep:xsd:rim:4.0"
                     xmlns:query="urn:oasis:names:tc:ebxml-regrep:xsd:query:4.0"
                     xmlns:sdg="http://data.europa.eu/p4s"
                     xmlns:rs="urn:oasis:names:tc:ebxml-regrep:xsd:rs:4.0"
                     xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
                     xmlns:xlink="http://www.w3.org/1999/xlink"
                     requestId="urn:uuid:${this.idRequete}"
                     status="urn:oasis:names:tc:ebxml-regrep:ResponseStatusType:Failure">

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

  <rim:Slot name="ErrorProvider">
  </rim:Slot>

  <rs:Exception xsi:type="${this.typeException}"
                message="${this.messageException}"
                severity="${this.severiteException}"
                code="${this.codeException}">
    <rim:Slot name="Timestamp">
      <rim:SlotValue xsi:type="rim:DateTimeValueType">
        <rim:Value>${this.horodateur?.maintenant()}</rim:Value>
      </rim:SlotValue>
    </rim:Slot>
  </rs:Exception>
</query:QueryResponse>`;
  }
}

Object.assign(ReponseErreur, DESCRIPTIONS_EXCEPTIONS);
module.exports = ReponseErreur;
