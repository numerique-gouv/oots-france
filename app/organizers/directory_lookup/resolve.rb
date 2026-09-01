module DirectoryLookup
  # Replays, on demand, the chain `EvidenceRequest::Fetch` walks before sending
  # anything: the requirements of a procedure, the evidence types satisfying
  # one of them, the providers holding one of those.
  #
  # It does not go through `Directories::CommonServices`. That façade turns a
  # refusal into the exception the interactors of a request expect; a console
  # wants the refusal code as the directory gave it.
  #
  # A step that fails stops the chain and leaves what the earlier ones found in
  # the context, which is the point: a refusal at the Data Service Directory
  # must not take the two Evidence Broker answers off the screen with it.
  class Resolve < ApplicationOrganizer
    organize FetchRequirements, FetchEvidenceTypes, FetchProviders
  end
end
