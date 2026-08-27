# The document an answer carries, as the MIME part that carried it, and the
# identifier that answer gave it. Chapter 4.8 asks the data service to log both,
# and neither means anything alone: an identifier naming no document names
# nothing.
#
# The pair therefore travels as one value where France builds the answer, so
# that what carries no document names no identifier. It says nothing of the way
# in: `AuditTrail#received_response` reads the identifier from the RegRep body
# and the part from the ebMS header, each under its own guard, precisely so that
# one unreadable half does not discard the other.
Evidence = Data.define(:part, :identifier)
