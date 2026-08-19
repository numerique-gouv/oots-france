# An entry a central directory published that the EDM rules refuse to carry —
# an identifier of the wrong shape, a distribution with no format.
#
# A `CommonServicesError` because it comes from the same place and fails the
# same exchange, but named apart because retrying will not help: `code` tells a
# directory's own refusal from an outage, and this is neither of the two.
class InvalidDirectoryEntry < CommonServicesError
end
