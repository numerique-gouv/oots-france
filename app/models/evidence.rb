# The document an answer carries, and the identifier that answer gave it.
# Chapter 4.8 asks the data service to log both, and neither means anything
# alone: an identifier naming no document names nothing.
#
# The pair therefore travels as one value, the way `MimePart` does for the first
# part of a message — so that what carries no document names no identifier,
# rather than a row asserting half of what the chapter asks for.
Evidence = Data.define(:content, :identifier)
