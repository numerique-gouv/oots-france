const middleware = (adaptateurEnvironnement) => {
  const verifieBeneficiaire = (requete, reponse, suite) => {
    const { beneficiaire } = requete.query;
    if (typeof beneficiaire === 'undefined' || beneficiaire === '') {
      reponse.status(422).send({ erreur: 'Le bénéficiaire doit être renseigné' });
    } else {
      suite();
    }
  };

  const verifieInterrupteurOOTS = (_requete, reponse, suite) => {
    if (adaptateurEnvironnement.avecRequetePieceJustificative()) {
      suite();
    } else {
      reponse.status(501).send('Not Implemented Yet!');
    }
  };

  return {
    verifieBeneficiaire,
    verifieInterrupteurOOTS,
  };
};

module.exports = middleware;
