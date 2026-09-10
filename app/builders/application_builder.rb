# Renders an OOTS message from an ERB template kept under `app/templates`.
#
# Templates rather than a programmatic builder, so the XML stays comparable by
# eye to the examples published with the TDD. Rendering happens outside
# ActionView, so nothing is escaped for us: every interpolated value that is
# not a literal goes through `escape`, from XmlEscaping.
class ApplicationBuilder
  include XmlEscaping

  # The EDM version this message is written in, which every template
  # interpolates and some branch on. Chapter 4.7 §2.6.2 has one exchange keep
  # one version from end to end, so it is decided upstream — by the
  # `ConformsTo` of the access point where France asks, by the request where
  # France answers — and never here.
  attr_reader :specification

  # ERB gets this method's binding, so a template looks constants up lexically
  # from here and must qualify them — `EvidenceResponseBuilder::ISSUING_DATE`,
  # never a bare `ISSUING_DATE`. Methods resolve on `self` and need no such care.
  def render = renderer.result(binding)

  protected

  def template_name = raise(NotImplementedError)

  # A template is doubled by version only where the two differ in structure, and
  # `evidence_response` is the one such case: 2.0 wraps the objects in a
  # `rim:RegistryPackageType` two levels deep, so a conditional would open a tag
  # in one branch and close it in the other, and the XML would stop being
  # readable by eye — which is the whole reason these are templates. Everywhere
  # else one file carries both versions, what changes being a value the builder
  # interpolates or a block a local condition covers.
  def versioned(stem) = "#{stem}.#{specification.slug}.xml.erb"

  private

  # `trim_mode: '-'` lets a template write `<%- -%>`, so a conditional block
  # does not leave a hole where its control tag was.
  def renderer = @renderer ||= ERB.new(template_path.read, trim_mode: '-')

  def template_path = Rails.root.join('app/templates', template_name)
end
