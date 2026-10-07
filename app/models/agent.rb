# Whoever identifies themself through ProConnect, admitted to the
# administration space or not: known here by the `email` claim alone, the one
# thing the console asks of them.
Agent = Data.define(:email) do
  # What follows the **last** `@`: an address may quote one in its local part,
  # never in its domain.
  def domain = email.to_s.rpartition('@').last.downcase

  # Equal to one of the admitted domains, to the character and regardless of
  # case — « 3.1. Restreindre au domaine email ». `numerique.gouv.fr` admits no
  # `sous.numerique.gouv.fr`: a subdomain is listed or refused.
  # https://partenaires.proconnect.gouv.fr/docs/fournisseur-service/restriction_acces
  def admitted_by?(domains)
    email.to_s.include?('@') && domains.map(&:downcase).include?(domain)
  end
end
