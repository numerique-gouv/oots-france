# ProConnect refused the sign-in, or what it sent back could not be read,
# verified or believed. One class for the whole exchange, because the console
# does one thing with all of them: it opens nothing, and says so.
class ProConnectError < StandardError
end
