# Renders one directory answer, the way `ApplicationBuilder` renders a message:
# plain ERB, so nothing is escaped for us, and the XML stays comparable by eye
# to the answers captured in `spec/fixtures/common_services/`.
class DirectoryAnswer
  include XmlEscaping

  TEMPLATES = 'features/support/common_services'.freeze

  # What this class already answers to. A value of that name would override it,
  # and the failure would surface far from the template that named it.
  OWN = %i[render path].freeze

  # The values become methods, so a template reads like the message templates
  # do and a missing one fails by name rather than by a silent blank.
  def initialize(template, values)
    reject_unless_free(values.keys)
    @template = template
    values.each { |name, value| define_singleton_method(name) { value } }
  end

  def render = ERB.new(path.read, trim_mode: '-').result(binding)

  private

  def reject_unless_free(names)
    taken = names.map(&:to_sym) & OWN
    raise ArgumentError, "Valeurs de gabarit réservées : #{taken.join(', ')}." unless taken.empty?
  end

  def path = Rails.root.join(TEMPLATES, @template)
end
