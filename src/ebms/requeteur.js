const adaptateurChiffrement = require('../adaptateurs/adaptateurChiffrement');
const PersonnePhysique = require('./personnePhysique');

class Requeteur {
  constructor(config = {}, donnees = {}) {
    this.adaptateurChiffrement = config.adaptateurChiffrement || adaptateurChiffrement;
    this.id = donnees.id;
    this.nom = donnees.nom;
    this.url = donnees.url;
  }

  beneficiaire(infosUtilisateurChiffrees) {
    const urlClesPubliques = `${this.url}/auth/cles_publiques`;

    return this.adaptateurChiffrement.dechiffreJWE(infosUtilisateurChiffrees, urlClesPubliques)
      .then(({ dateNaissance, nomUsage, prenom }) => (
        new PersonnePhysique({ dateNaissance, nom: nomUsage, prenom })
      ));
  }

  identifiantEtNomEnXML() {
    return `<sdg:Identifier schemeID="urn:oasis:names:tc:ebcore:partyid-type:unregistered:FR">${this.id}</sdg:Identifier>
        <sdg:Name lang="FR">${this.nom}</sdg:Name>`;
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
    `;
  }

  enXMLPourRequete() {
    return `
<rim:Slot name="EvidenceRequester">
  <rim:SlotValue xsi:type="rim:CollectionValueType" collectionType="urn:oasis:names:tc:ebxml-regrep:CollectionType:Set">
    <rim:Element xsi:type="rim:AnyValueType">
      <sdg:Agent>
        ${this.identifiantEtNomEnXML()}
        <sdg:Classification>ER</sdg:Classification>
      </sdg:Agent>
    </rim:Element>
    <rim:Element xsi:type="rim:AnyValueType">
      <sdg:Agent>
        <sdg:Identifier schemeID="urn:oasis:names:tc:ebcore:partyid-type:unregistered:FR">OOTSFRANCE</sdg:Identifier>
        <sdg:Name lang="EN">OOTS-France Intermediary Platform</sdg:Name>
        <sdg:Classification>IP</sdg:Classification>
      </sdg:Agent>
    </rim:Element>
  </rim:SlotValue>
</rim:Slot>
    `;
  }
}

module.exports = Requeteur;
