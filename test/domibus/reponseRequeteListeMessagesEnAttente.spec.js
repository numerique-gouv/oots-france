const ReponseRequeteListeMessagesEnAttente = require('../../src/domibus/reponseRequeteListeMessagesEnAttente');

class ConstructeurReponse {
  constructor() {
    this.identifiantsMessage = [];
  }

  avecIdentifiantMessage(id) {
    this.identifiantsMessage.push(id);
    return this;
  }

  construis() {
    return new ReponseRequeteListeMessagesEnAttente(`
<soap:Envelope xmlns:soap="http://www.w3.org/2003/05/soap-envelope">
  <soap:Body>
    <ns4:listPendingMessagesResponse xmlns:ns4="http://eu.domibus.wsplugin/">
      ${this.identifiantsMessage.map((id) => `<messageID>${id}</messageID>`).join()}
    </ns4:listPendingMessagesResponse>
  </soap:Body>
</soap:Envelope>
    `);
  }
}

describe('La réponse à une requête Domibus de liste de messages en attente', () => {
  it('connaît le prochain identifiant de message quand plusieurs messages en attente', () => {
    const reponse = new ConstructeurReponse()
      .avecIdentifiantMessage('11111111-1111-1111-1111-111111111111@oots.eu')
      .avecIdentifiantMessage('22222222-2222-2222-2222-222222222222@oots.eu')
      .construis();

    expect(reponse.idMessageSuivant()).toEqual('11111111-1111-1111-1111-111111111111@oots.eu');
  });

  it('retourne le prochain identifiant de message quand un seul message en attente', () => {
    const reponse = new ConstructeurReponse()
      .avecIdentifiantMessage('11111111-1111-1111-1111-111111111111@oots.eu')
      .construis();

    expect(reponse.idMessageSuivant()).toEqual('11111111-1111-1111-1111-111111111111@oots.eu');
  });

  it('retourne `undefined` si aucun message en attente', () => {
    const reponse = new ConstructeurReponse()
      .construis();

    expect(reponse.idMessageSuivant()).toBeUndefined();
  });

  it('indique si un message est en attente', () => {
    let reponse = new ConstructeurReponse()
      .avecIdentifiantMessage('11111111-1111-1111-1111-111111111111@oots.eu')
      .construis();
    expect(reponse.messageEnAttente()).toBe(true);

    reponse = new ConstructeurReponse().construis();
    expect(reponse.messageEnAttente()).toBe(false);
  });
});
