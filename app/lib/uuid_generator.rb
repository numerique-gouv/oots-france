# Injected wherever a message needs an identifier, so a test can make them
# predictable. Every UUID in an outgoing message comes through here.
class UuidGenerator
  def next = SecureRandom.uuid
end
