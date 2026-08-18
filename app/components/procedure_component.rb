# A procedure code and the title the code list gives it.
#
# Not boxed like a country: a title runs to a full line, and a box around one
# frames a paragraph rather than marking a term. The code keeps a column of its
# own and the title wraps in the next.
class ProcedureComponent < ViewComponent::Base
  NO_LABEL = 'admin.common_services.procedures.no_label'.freeze

  # The longest titles the code list publishes fill a card on their own.
  MAX_LABEL = 200

  # `limit: nil` where the title is what the reader came for — the heading of
  # the procedure's own page —, and where nothing else would carry the rest.
  def self.label(code, name = nil, limit: MAX_LABEL)
    return '—' if code.blank?

    title = name.presence || I18n.t(NO_LABEL)

    "#{code} — #{limit ? title.truncate(limit) : title}"
  end

  # What a `title` attribute has left to say, and nothing when it has nothing.
  def self.hint(name)
    name if name.to_s.length > MAX_LABEL
  end

  def initialize(code:, name: nil, href: nil)
    @code = code
    @name = name
    @href = href
    super()
  end

  def code = @code.presence || '—'

  def name = (@name.presence || t(NO_LABEL)).truncate(MAX_LABEL)

  def tag_name = @href.present? ? :a : :span

  def attributes
    { class: ['procedure', ('fr-link' if @href.present?)], href: @href.presence, title: self.class.hint(@name) }
  end
end
