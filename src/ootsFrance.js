const express = require('express');

const JustificatifEducation = require('./vues/justificatifEducation');

const creeServeur = (config) => {
  const { adaptateurUUID } = config;
  let serveur;
  const app = express();

  app.get('/response/educationEvidence', (_requete, reponse) => {
    const uuid = adaptateurUUID.genereUUID();
    const justificatif = new JustificatifEducation(uuid);

    reponse.set('Content-Type', 'text/xml');
    reponse.send(justificatif.enXML());
  });

  app.get('/request/educationEvidence', (_requete, reponse) => {
    reponse.set('Content-Type', 'text/xml');
    reponse.send(`<?xml version="1.0" encoding="UTF-8"?>
<query:QueryRequest xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
  xmlns:rs="urn:oasis:names:tc:ebxml-regrep:xsd:rs:4.0" xmlns:sdg="http://data.europa.eu/p4s"
  xmlns:xmime="http://www.w3.org/2005/05/xmlmime"
  xmlns:rim="urn:oasis:names:tc:ebxml-regrep:xsd:rim:4.0"
  xmlns:query="urn:oasis:names:tc:ebxml-regrep:xsd:query:4.0"
  xmlns:xlink="http://www.w3.org/1999/xlink"
  xml:lang="DE"
  id="urn:uuid:4ffb5281-179d-4578-adf2-39fd13ccc797">
  <rim:Slot name="SpecificationIdentifier"/>
  <rim:Slot name="IssueDateTime"/>
  <rim:Slot name="Procedure"/>
  <rim:Slot name="PossibilityForPreview"/>
  <rim:Slot name="ExplicitRequestGiven"/>
  <rim:Slot name="Requirements"/>
  <rim:Slot name="EvidenceRequester"/>
  <rim:Slot name="EvidenceProvider"/>
  <query:ResponseOption returnType="LeafClassWithRepositoryItem"/>
  <query:Query queryDefinition="DocumentQuery">
    <rim:Slot name="EvidenceRequest"/>
    <rim:Slot name="NaturalPerson"/>
  </query:Query>
</query:QueryRequest>`);
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
