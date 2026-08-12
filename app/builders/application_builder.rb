# Renders an OOTS message from an ERB template kept under `app/templates`.
#
# Templates rather than a programmatic builder, so the XML stays comparable by
# eye to the examples published with the TDD. Rendering happens outside
# ActionView, so nothing is escaped for us: every interpolated value that is
# not a literal goes through `escape`, from XmlEscaping.
class ApplicationBuilder
  include XmlEscaping

  # ERB gets this method's binding, so a template looks constants up lexically
  # from here and must qualify them — `SystemCheckResponseBuilder::ISSUING_DATE`,
  # never a bare `ISSUING_DATE`. Methods resolve on `self` and need no such care.
  def render = renderer.result(binding)

  protected

  def template_name = raise(NotImplementedError)

  private

  # `trim_mode: '-'` lets a template write `<%- -%>`, so a conditional block
  # does not leave a hole where its control tag was.
  def renderer = @renderer ||= ERB.new(template_path.read, trim_mode: '-')

  def template_path = Rails.root.join('app/templates', template_name)
end
