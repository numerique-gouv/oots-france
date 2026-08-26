# One part of a multipart message: how the message refers to it, what it
# declares itself to be, and what it holds. Chapter 4.8 asks the log for the
# type and the content of the *first* part, and asks for them together — a
# content whose type nothing declares answers the chapter no better than a type
# with nothing under it. Of the part carrying the evidence it asks for the type
# and the content identifier, « for evidence content referenced using
# `rim:RepositoryItemRef` elements ».
#
# The three therefore travel as one value, so that a part that could not be read
# at all writes nothing rather than a row asserting what it cannot show.
#
# What each field holds is another matter, and none is guaranteed well formed on
# the way in: `mime_type` is nil when an arriving `eb:PartInfo` declares no
# `MimeType` property, and `content` is tagged UTF-8 without being validated as
# such. What a correspondent sent is kept as sent — a log archives, it does not
# vet. One built for a message going out carries neither surprise.
MimePart = Data.define(:mime_type, :content_id, :content)
