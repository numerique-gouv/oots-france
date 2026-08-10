const EnteteErreur = require('./enteteErreur')
const Message = require('./message')
const { IDENTIFIANT_SPECIFICATION_EDM } = require('./specificationEdm')
const { echappeXML } = require('./echappement')
const { exigeIdentite } = require('./identiteEbms')

const SEVERITE_ERREUR = 'urn:oasis:names:tc:ebxml-regrep:ErrorSeverityType:Error'

// Sévérité propre à OOTS, réservée à l'erreur qui redirige vers un espace de
// prévisualisation : `R-EDM-ERR-C022` l'exige dès qu'un slot `PreviewLocation`
// accompagne l'exception.
const SEVERITE_PREVISUALISATION_REQUISE = 'urn:sr.oots.tech.ec.europa.eu:codes:ErrorSeverity:EDMErrorResponse:PreviewRequired'

// Les huit codes de la liste officielle `EDMErrorCodes` publiée avec les TDD :
// https://code.europa.eu/oots/tdd/tdd_chapters/-/blob/2.0.1/OOTS-EDM/codelists/OOTS/EDMErrorCodes-CodeList.gc
// `code`, `type` et `message` en sont recopiés colonne par colonne (`code`,
// `name-Type`, `name-Value`) : rien n'y est un choix local.
const DESCRIPTIONS_EXCEPTIONS = {
  AUTHENTICATION_EXCEPTION: {
    type: 'rs:AuthenticationExceptionType',
    message: 'Failed Authentication',
    severite: SEVERITE_ERREUR,
    code: 'EDM:ERR:0001',
  },
  AUTHORIZATION_EXCEPTION: {
    type: 'rs:AuthorizationExceptionType',
    message: 'Missing Authorization',
    severite: SEVERITE_PREVISUALISATION_REQUISE,
    code: 'EDM:ERR:0002',
  },
  INVALID_REQUEST_EXCEPTION: {
    type: 'rs:InvalidRequestExceptionType',
    message: 'Syntactically or semantically invalid request',
    severite: SEVERITE_ERREUR,
    code: 'EDM:ERR:0003',
  },
  OBJECT_NOT_FOUND_EXCEPTION: {
    type: 'rs:ObjectNotFoundExceptionType',
    message: 'Object not found',
    severite: SEVERITE_ERREUR,
    code: 'EDM:ERR:0004',
  },
  TIMEOUT_EXCEPTION: {
    type: 'rs:TimeoutExceptionType',
    message: 'Exceeding timeout period',
    severite: SEVERITE_ERREUR,
    code: 'EDM:ERR:0005',
  },
  UNRESOLVED_REFERENCE_EXCEPTION: {
    type: 'rs:UnresolvedReferenceExceptionType',
    message: 'Referenced object that cannot be resolved',
    severite: SEVERITE_ERREUR,
    code: 'EDM:ERR:0006',
  },
  UNSUPPORTED_CAPABILITY_EXCEPTION: {
    type: 'rs:UnsupportedCapabilityExceptionType',
    message: 'Optional feature or capability is not supported',
    severite: SEVERITE_ERREUR,
    code: 'EDM:ERR:0007',
  },
  QUERY_EXCEPTION: {
    type: 'query:QueryExceptionType',
    message: 'Invalid query syntax or semantics that must be corrected',
    severite: SEVERITE_ERREUR,
    code: 'EDM:ERR:0008',
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
