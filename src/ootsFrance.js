const express = require('express');

const creeServeur = (config) => {
  const { adaptateurUUID } = config;
  let serveur;
  const app = express();

  app.get('/response/educationEvidence', (_requete, reponse) => {
    const uuid = adaptateurUUID.genereUUID();

    reponse.set('Content-Type', 'text/xml');
    reponse.send(`<?xml version="1.0" encoding="UTF-8"?>
<query:QueryResponse xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
    xmlns:rs="urn:oasis:names:tc:ebxml-regrep:xsd:rs:4.0"
    xmlns:rim="urn:oasis:names:tc:ebxml-regrep:xsd:rim:4.0" xmlns:sdg="http://data.europa.eu/p4s"
    xmlns:query="urn:oasis:names:tc:ebxml-regrep:xsd:query:4.0"
    xmlns:xlink="http://www.w3.org/1999/xlink"
    status="urn:oasis:names:tc:ebxml-regrep:ResponseStatusType:Success"
    requestId="urn:uuid:${uuid}">
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
</query:QueryResponse>`);
  });

  app.get('/', (_requete, reponse) => {
    reponse.status(504).send('Not Implemented Yet!');
  });

  const ecoute = (...args) => { serveur = app.listen(...args); };

  const arreteEcoute = () => serveur.close();

  return {
    arreteEcoute,
    ecoute,
  };
};

module.exports = { creeServeur };
