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
# A column is asked for by its `ShortName` and found by its `Id`, which is what
# each `Value/@ColumnRef` points at. The lists published with the TDD give both
# the same spelling, where the template chapter 3.1.4 §4.4.3.3 sets for a list of
# provider classifications has « Column Ids MUST in all cases be UUID ».
#
# Nothing is validated. A document that is not a code list at all yields no
# rows, which reads exactly like a code list with none — a distinction neither
# caller makes either: `CodeListClient` loses the names, `ClassificationValuesClient`
# asks its question in a text field.
class GenericodeParser
  def initialize(body)
    @document = Nokogiri::XML(body)
  end

  def names(code_column:, name_column:)
    rows(code_column, name_column).filter_map { |row|
      [row[code_column], row[name_column]] if row[code_column].present? && row[name_column].present?
    }.to_h
  end

  # Every row, in the order the list publishes them, as the value of each
  # column asked for — nil where the row leaves it out.
  def rows(*columns)
    references = columns.index_with { |column| reference(column) }

    @document.xpath('//SimpleCodeList/Row').map do |row|
      references.transform_values { |id| value(row, id) }
    end
  end

  private

  # The column's own spelling when the `ColumnSet` does not declare it, which is
  # how a list referencing its columns by name reads.
  def reference(short_name)
    @document.xpath('//ColumnSet/Column').find { |column| column.at_xpath('./ShortName')&.text&.strip == short_name }
      &.[]('Id') || short_name
  end

  # Newlines and indentation survive in the published file, and a name read
  # from it lands in a table cell.
  def value(row, column)
    row.at_xpath('./Value[@ColumnRef=$column]/SimpleValue', nil, column:)&.text&.squish
  end
end
