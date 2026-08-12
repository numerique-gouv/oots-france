# Raised when the request the local service provider sent us cannot be honoured
# — an unknown procedure, a country with no provider, an evidence type absent
# from the directory. These drive a 422 back to that caller, because the fault
# is theirs.
#
# Deliberately distinct from UnreadableMessageError, which covers a malformed
# message from a *foreign* correspondent: that one is not our caller's fault,
# and answering it with a 422 would blame the wrong party.
class EbmsError < StandardError
end
