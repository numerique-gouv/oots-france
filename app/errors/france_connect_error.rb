# FranceConnect+ refused the identification, or what it sent back could not be
# opened, verified or believed.
#
# One class for the whole exchange with the portal — the refusal it redirects
# with, the token endpoint answering an error, a signature that does not check
# out, an identifier the specification refuses — because the demonstration does
# one thing with all of them: it holds no identity and sends the operator back
# to the start, saying why.
class FranceConnectError < StandardError
end
