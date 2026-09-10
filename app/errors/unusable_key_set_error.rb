# A published key set could not be turned into a key to use.
#
# Deliberately not an EbmsError: that family drives a 422 back to the French
# service provider, and a JWKS answered as a maintenance page — or published
# empty — is not their doing. It is the reading counterpart of what
# `BeneficiaryToken` and `FranceConnectToken` already turn into named errors of
# their own: a document fetched over HTTP is unusable in more ways than being
# unreachable, and the boundary that reads it is the one that has to say so.
class UnusableKeySetError < StandardError
end
