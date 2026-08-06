const adaptateurChiffrement = require('../adaptateurs/adaptateurChiffrement')
const Adresse = require('./adresse')
const PersonnePhysique = require('./personnePhysique')
const { echappeXML } = require('./echappement')
const { SCHEME_ID_FRANCAIS, SCHEME_ID_REPLI_FRANCAIS } = require('./schemeIdentifiant')
const { identiteEbms } = require('./identiteEbms')

// OOTS-France se déclare en second agent de chaque requête, comme plateforme
// intermédiaire. Faute de SIRET renseigné, son identité garde le schéma de
// repli : l'annoncer en EAS:0009 promettrait un SIRET que `OOTSFRANCE` n'est
// pas. Voir « Identifier une organisation » dans docs/oots_context.md.
const PLATEFORME_INTERMEDIAIRE = identiteEbms(
  { id: 'OOTSFRANCE', typeId: SCHEME_ID_REPLI_FRANCAIS },
  'La plateforme intermédiaire',
)
PLATEFORME_INTERMEDIAIRE.nom = 'OOTS-France Intermediary Platform'

class Requeteur {
  constructor(config = {}, donnees = {}) {
    this.adaptateurChiffrement = config.adaptateurChiffrement || adaptateurChiffrement
    this.id = donnees.id
    this.nom = donnees.nom
    this.url = donnees.url
    // Les requêteurs français sont enregistrés localement, sans schéma
    // d'identifiant ; ceux venus d'un autre État membre portent celui lu dans
    // leur message. Seule son absence vaut « français » : un schéma vide est
    // une donnée fautive, que `identiteEbms` refusera plutôt que de la
    // maquiller en identité française.
    this.typeId = donnees.typeId ?? SCHEME_ID_FRANCAIS
    // De même pour la langue du nom : celle du message reçu, à défaut le
    // français. Annoncer `FR` sur le nom d'un requêteur danois serait faux.
    this.langue = donnees.langue ?? 'FR'
    // Toujours française : l'adresse n'est émise que pour l'agent `ER`, que
    // ce dépôt n'occupe que lorsqu'il est lui-même le requêteur.
    this.adresse = new Adresse()
  }

  identiteEbms() {
    return identiteEbms(this, 'Le requêteur')
  }

  beneficiaire(infosUtilisateurChiffrees) {
    const urlClesPubliques = `${this.url}/auth/cles_publiques`

    return this.adaptateurChiffrement.dechiffreJWE(infosUtilisateurChiffrees, urlClesPubliques)
      .then(({ dateNaissance, nomUsage, prenom }) => (
        new PersonnePhysique({ dateNaissance, nom: nomUsage, prenom })
      ))
  }

  identifiantEtNomEnXML() {
    return `<sdg:Identifier schemeID="${echappeXML(this.typeId)}">${echappeXML(this.id)}</sdg:Identifier>
        <sdg:Name lang="${echappeXML(this.langue)}">${echappeXML(this.nom)}</sdg:Name>`
  }

  enXMLPourReponse() {
    return `
<rim:Slot name="EvidenceRequester">
  <rim:SlotValue xsi:type="rim:AnyValueType">
    <sdg:Agent>
      ${this.identifiantEtNomEnXML()}
    </sdg:Agent>
  </rim:SlotValue>
</rim:Slot>
    `
  }

  enXMLPourRequete() {
    return `
<rim:Slot name="EvidenceRequester">
  <rim:SlotValue xsi:type="rim:CollectionValueType" collectionType="urn:oasis:names:tc:ebxml-regrep:CollectionType:Set">
    <rim:Element xsi:type="rim:AnyValueType">
      <sdg:Agent>
        ${this.identifiantEtNomEnXML()}
        ${this.adresse.enXML()}
        <sdg:Classification>ER</sdg:Classification>
      </sdg:Agent>
    </rim:Element>
    <rim:Element xsi:type="rim:AnyValueType">
      <sdg:Agent>
        <sdg:Identifier schemeID="${echappeXML(PLATEFORME_INTERMEDIAIRE.typeId)}">${echappeXML(PLATEFORME_INTERMEDIAIRE.id)}</sdg:Identifier>
        <sdg:Name lang="EN">${echappeXML(PLATEFORME_INTERMEDIAIRE.nom)}</sdg:Name>
        <sdg:Classification>IP</sdg:Classification>
      </sdg:Agent>
    </rim:Element>
  </rim:SlotValue>
</rim:Slot>
    `
  }
}

module.exports = Requeteur
