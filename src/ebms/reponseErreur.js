const EnteteErreur = require('./enteteErreur')
const Message = require('./message')
const { IDENTIFIANT_SPECIFICATION_EDM } = require('./specificationEdm')
const { echappeXML } = require('./echappement')
const { exigeIdentite } = require('./identiteEbms')

const DESCRIPTIONS_EXCEPTIONS = {
  OBJECT_NOT_FOUND_EXCEPTION: {
    type: 'rs:ObjectNotFoundExceptionType',
    message: 'Object not found',
    severite: 'urn:oasis:names:tc:ebxml-regrep:ErrorSeverityType:Error',
    code: 'EDM:ERR:0004',
  },
}

class ReponseErreur extends Message {
  static ClasseEntete = EnteteErreur

  constructor(
    config,
    {
      destinataire,
      exception,
      fournisseur = config.fournisseurFrancais,
      idConversation,
      idEchange,
      idRequete,
      requeteur,
    } = {},
  ) {
    super(config, {
      destinataire,
      idConversation,
      idEchange,
      emetteurOriginal: exigeIdentite(fournisseur, 'Le fournisseur français'),
      destinataireFinal: exigeIdentite(requeteur, 'Le requêteur'),
    })

    this.fournisseur = fournisseur
    this.idRequete = idRequete
    this.requeteur = requeteur
    this.typeException = exception?.type
    this.messageException = exception?.message
    this.severiteException = exception?.severite
    this.codeException = exception?.code
  }

  corpsMessageEnXML() {
    return `<?xml version="1.0" encoding="UTF-8"?>
<query:QueryResponse xmlns:rim="urn:oasis:names:tc:ebxml-regrep:xsd:rim:4.0"
                     xmlns:query="urn:oasis:names:tc:ebxml-regrep:xsd:query:4.0"
                     xmlns:sdg="http://data.europa.eu/p4s"
                     xmlns:rs="urn:oasis:names:tc:ebxml-regrep:xsd:rs:4.0"
                     xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
                     xmlns:xlink="http://www.w3.org/1999/xlink"
                     requestId="${echappeXML(this.idRequete)}"
                     status="urn:oasis:names:tc:ebxml-regrep:ResponseStatusType:Failure">

  <rim:Slot name="SpecificationIdentifier">
    <rim:SlotValue xsi:type="rim:StringValueType">
      <rim:Value>${IDENTIFIANT_SPECIFICATION_EDM}</rim:Value>
    </rim:SlotValue>
  </rim:Slot>

  <rim:Slot name="EvidenceResponseIdentifier">
    <rim:SlotValue xsi:type="rim:StringValueType">
      <rim:Value>${this.idDocument}</rim:Value>
    </rim:SlotValue>
  </rim:Slot>

  ${this.fournisseur.enXMLPourErreur()}
  ${this.requeteur.enXMLPourReponse()}

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
</query:QueryResponse>`
  }
}

Object.assign(ReponseErreur, DESCRIPTIONS_EXCEPTIONS)
module.exports = ReponseErreur
