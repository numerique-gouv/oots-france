# Something the Semantic Repository names, and whose identifier is therefore a
# URL: a requirement, an evidence type classification.
#
# The console addresses its own pages by the last segment of that URL rather
# than by the URL itself. The host differs between acceptance and production —
# `sr.acc.oots.tech.ec.europa.eu` and `sr.oots.tech.ec.europa.eu` — so a path
# built from the whole identifier would not survive the move, and would have to
# be escaped into a segment on top of that.
module SemanticRepositoryAsset
  extend ActiveSupport::Concern

  def uuid = id&.split('/')&.last

  # What a page calls it. Every entry of the catalogue carries an English name,
  # but a directory is not obliged to publish one, and a row named after
  # nothing would be a row nobody can click.
  def display_name = label || uuid
end
