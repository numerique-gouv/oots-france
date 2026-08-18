# A code list as OASIS [genericode](http://docs.oasis-open.org/codelist/genericode/doc/oasis-code-list-representation-genericode.html)
# publishes it, which is the form the TDD give theirs (chapter 3.5.1).
#
# A list is a set of rows, each a bag of values keyed by the column it belongs
# to. The columns of an OOTS list are one code and one name per language of the
# Union, so reading it is choosing a column.
#
# Only the root element carries a namespace, everything below it carries none:
# the paths here are therefore plain, and the `gc` prefix appears nowhere.
#
# Nothing is validated. A document that is not a code list at all yields no
# rows, which reads exactly like a code list with none — a distinction its only
# caller does not make either, and says so where it decides that a name it
# cannot read costs nothing but the name.
class GenericodeParser
  def initialize(body)
    @document = Nokogiri::XML(body)
  end

  def names(code_column:, name_column:)
    rows.filter_map { |row| entry(row, code_column, name_column) }.to_h
  end

  private

  def rows = @document.xpath('//SimpleCodeList/Row')

  def entry(row, code_column, name_column)
    code = value(row, code_column)
    name = value(row, name_column)

    [code, name] if code.present? && name.present?
  end

  # Newlines and indentation survive in the published file, and a name read
  # from it lands in a table cell.
  def value(row, column)
    row.at_xpath("./Value[@ColumnRef='#{column}']/SimpleValue")&.text&.squish
  end
end
