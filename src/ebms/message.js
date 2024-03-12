const PieceJointeVide = require('./pieceJointeVide');

class Message {
  constructor(config, donnees) {
    this.adaptateurUUID = config.adaptateurUUID;
    this.horodateur = config.horodateur;

    this.pieceJointe = donnees.pieceJointe || new PieceJointeVide();

    const suffixe = process.env.SUFFIXE_IDENTIFIANTS_DOMIBUS;
    this.idPayload = `cid:${this.adaptateurUUID.genereUUID()}@${suffixe}`;
    this.entete = new this.constructor.ClasseEntete(
      config,
      { ...donnees, idPayload: this.idPayload },
    );
  }

  pieceJointePresente = () => this.pieceJointe.constructor.name === 'PieceJointe';

  enSOAP() {
    const messageEnBase64 = Buffer.from(this.corpsMessageEnXML()).toString('base64');

    return `
<soap:Envelope
  xmlns:soap="http://www.w3.org/2003/05/soap-envelope"
  xmlns:ns="http://docs.oasis-open.org/ebxml-msg/ebms/v3.0/ns/core/200704/"
  xmlns:_1="http://eu.domibus.wsplugin/"
  xmlns:xm="http://www.w3.org/2005/05/xmlmime">

  <soap:Header>${this.entete.enXML()}</soap:Header>

  <soap:Body>
    <_1:submitRequest>
      <bodyload>
        <value>cid:bodyload</value>
      </bodyload>
      <payload payloadId="${this.idPayload}" contentType="application/x-ebrs+xml">
        <value>${messageEnBase64}</value>
      </payload>
      ${this.pieceJointe.enXMLDansCorps()}
    </_1:submitRequest>
  </soap:Body>
</soap:Envelope>
    `;
  }
}

module.exports = Message;
