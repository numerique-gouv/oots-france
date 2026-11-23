# The evidence type a card's button asks for: the first its card names, the
# one a click may ask for before any document is in hand. `nil` before the page
# has named it.
module DemoNamedType
  def named_type(requirement_uuid)
    Demo::Card.find_by(requirement_uuid:)&.named_evidences.to_a.first&.evidence_type_uuid
  end
end

RSpec.configure do |config|
  config.include DemoNamedType, type: :request
end
