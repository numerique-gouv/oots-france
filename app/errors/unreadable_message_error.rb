# A message from a foreign correspondent that we cannot read: a slot missing,
# a slot present but empty, an identity we cannot extract.
#
# Flat, and not an EbmsError, on purpose: EbmsError drives the 422 we return to
# the French service provider, and a malformed foreign message is not their
# fault. This one turns into an `EDM:ERR:0003` RegRep response addressed to the
# correspondent instead.
class UnreadableMessageError < StandardError
end
