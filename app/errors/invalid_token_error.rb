# The beneficiary token could not be opened, or its signature did not check out.
#
# Reported to the French service provider as a 422, like the EbmsError family:
# it is the caller's token, and it is the caller who can fix it.
class InvalidTokenError < EbmsError
end
