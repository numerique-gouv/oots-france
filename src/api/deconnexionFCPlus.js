const deconnexionFCPlus = (requete, reponse) => {
  requete.session = null;
  reponse.redirect('/');
};

module.exports = deconnexionFCPlus;
