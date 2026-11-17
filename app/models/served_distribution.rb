# The distribution an evidence France serves is in, as its response describes
# it: `sdg:Format`, `sdg:Language` where the document is written in one, and
# the `xlink:title` of the `rim:RepositoryItemRef` that points at it.
class ServedDistribution < Data.define(:format, :language, :title)
  # The test document of `EvidenceDocumentBuilder`.
  PDF = new(format: EvidenceType::PDF, language: nil, title: 'Evidence')
end
