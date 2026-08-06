const fs = require('fs')

const EnteteReponse = require('./enteteReponse')
const Message = require('./message')
const PieceJointe = require('./pieceJointe')
const { IDENTIFIANT_SPECIFICATION_EDM } = require('./specificationEdm')
const { echappeXML } = require('./echappement')
const { exigeIdentite } = require('./identiteEbms')

class ReponseVerificationSysteme extends Message {
  static ClasseEntete = EnteteReponse

  constructor(config, donnees) {
    const pieceJointe = new PieceJointe(
      `cid:${config.adaptateurUUID.genereUUID()}@pdf.oots.fr`,
      fs.readFileSync('./assets/drapeau.pdf').toString('base64'),
    )

    const fournisseur = donnees.fournisseur || config.fournisseurFrancais

    // Sur la réponse, les coins s'inversent : le fournisseur devient l'émetteur
    // d'origine et le requêteur le destinataire final.
    super(config, {
      ...donnees,
      pieceJointe,
      emetteurOriginal: exigeIdentite(fournisseur, 'Le fournisseur français'),
      destinataireFinal: exigeIdentite(donnees.requeteur, 'Le requêteur'),
    })

    this.beneficiaire = donnees.beneficiaire
    this.fournisseur = fournisseur
    this.idRequete = donnees.idRequete
    this.requeteur = donnees.requeteur
    this.typeJustificatif = donnees.typeJustificatif
  }

  corpsMessageEnXML() {
    return `<query:QueryResponse
        xmlns:query="urn:oasis:names:tc:ebxml-regrep:xsd:query:4.0"
        xmlns:rim="urn:oasis:names:tc:ebxml-regrep:xsd:rim:4.0"
        xmlns:sdg="http://data.europa.eu/p4s"
        xmlns:xlink="http://www.w3.org/1999/xlink"
        xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
        status="urn:oasis:names:tc:ebxml-regrep:ResponseStatusType:Success"
        requestId="${echappeXML(this.idRequete)}">

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

  <rim:Slot name="IssueDateTime">
    <rim:SlotValue xsi:type="rim:DateTimeValueType">
      <rim:Value>${this.horodateur.maintenant()}</rim:Value>
    </rim:SlotValue>
  </rim:Slot>

  ${this.fournisseur.enXMLPourReponse()}

  ${this.requeteur.enXMLPourReponse()}

  <rim:RegistryObjectList>
    <rim:RegistryObject xsi:type="rim:RegistryPackageType" id="urn:uuid:${this.adaptateurUUID.genereUUID()}">
      <rim:RegistryObjectList>
        <rim:RegistryObject xsi:type="rim:ExtrinsicObjectType" id="urn:uuid:${this.adaptateurUUID.genereUUID()}">
          <rim:Slot name="EvidenceMetadata">
            <rim:SlotValue xsi:type="rim:AnyValueType">
              <sdg:Evidence>
                <sdg:Identifier>${this.adaptateurUUID.genereUUID()}</sdg:Identifier>
                <sdg:IsAbout>${this.beneficiaire.enXMLPourReponse()}</sdg:IsAbout>
                ${this.fournisseur.enXMLAutoriteEmettrice()}
                <sdg:IsConformantTo>${this.typeJustificatif.enXMLPourReponse()}</sdg:IsConformantTo>
                <sdg:IssuingDate>1970-03-03</sdg:IssuingDate>
                <sdg:Distribution>
                  <sdg:Format>application/pdf</sdg:Format>
                </sdg:Distribution>
              </sdg:Evidence>
            </rim:SlotValue>
          </rim:Slot>
          <rim:Classification id="urn:uuid:${this.adaptateurUUID.genereUUID()}" classificationScheme="urn:fdc:oots:classification:edm" classificationNode="MainEvidence"/>
          <rim:RepositoryItemRef xlink:href="${this.pieceJointe.identifiant}" xlink:title="Evidence"/>
        </rim:RegistryObject>
      </rim:RegistryObjectList>
    </rim:RegistryObject>
  </rim:RegistryObjectList>
</query:QueryResponse>
    `
  }
}

module.exports = ReponseVerificationSysteme
