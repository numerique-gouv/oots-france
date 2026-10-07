module DirectoryLookup
  # The chain `Resolve` walks, from a requirement the caller already holds:
  # chapter 3.2.4 §4.3 bases the second query of the Evidence Broker « on a
  # requirement that is known to the Procedure Portal or that is determined via
  # the Evidence Broker's first query », so the first is not asked, and no
  # procedure has to declare the requirement.
  class ResolveRequirement < ApplicationOrganizer
    organize FetchEvidenceTypes, FetchProviders
  end
end
