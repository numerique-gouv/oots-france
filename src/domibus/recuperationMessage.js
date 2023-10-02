const { XMLParser } = require('fast-xml-parser');

const requeteRecuperationMessage = (idMessage) => `
<soap:Envelope xmlns:soap="http://www.w3.org/2003/05/soap-envelope" xmlns:_1="http://eu.domibus.wsplugin/">
  <soap:Header/>
  <soap:Body>
    <_1:retrieveMessageRequest>
      <messageID>${idMessage}</messageID>
    </_1:retrieveMessageRequest>
  </soap:Body>
</soap:Envelope>
  `;

const reponseRecuperationMessage = (donnees) => {
  const parser = new XMLParser({ ignoreAttributes: false });
  const xml = parser.parse(donnees);

  const urlRedirection = () => {
    const messageReponseEncode = xml['soap:Envelope']['soap:Body']['ns4:retrieveMessageResponse'].payload.value;
    const messageReponseDecode = Buffer.from(messageReponseEncode, 'base64').toString('ascii');

    return parser.parse(messageReponseDecode)['query:QueryResponse']['rs:Exception']['rim:Slot']
      .find((slot) => slot['@_name'] === 'PreviewLocation')['rim:SlotValue']['rim:Value'];
  };

  return { urlRedirection };
};

module.exports = { requeteRecuperationMessage, reponseRecuperationMessage };
