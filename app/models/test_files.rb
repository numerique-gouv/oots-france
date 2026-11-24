# The files of one execution of a Commission test case, drawn from what the
# journal kept of a conversation: the ebMS header and the RegRep body of each
# message, one file each, named `<Test ID>_<fileType>.xml` after the convention
# of the testing event of November 2026 — `HReq1`, `EvReq1`, `HRes1`, `EvRes1`…
# The test identifier is `<requester><provider>-<test case>-<run>`.
#
# Takes the exchanges in the order the conversation page shows them, each with
# its events loaded.
class TestFiles
  include Enumerable

  Entry = Data.define(:exchange, :name, :content)

  MESSAGE_TYPES = (AuditEvent::SENT_BY_FRANCE + AuditEvent::RECEIVED_BY_FRANCE).freeze

  # The country of an incoming exchange is what the correspondent wrote, kept
  # even when `R-EDM-REQ-C015` refused it: only a code of the list may enter a
  # file name, where a value like `../x` would escape the folder the archive is
  # unzipped into.
  def initialize(exchanges, test_case:, run:)
    @exchanges = exchanges.select { |exchange| CountryIdentificationCode.valid?(exchange.country_code) }
    @test_case = test_case
    @run = run
  end

  def each(&) = files.each(&)

  def archive_name = "#{test_id(first_exchange_with_files)}.zip"

  private

  # The convention numbers requests and responses without saying at which
  # scale. They are counted per test identifier, across the exchanges of the
  # conversation: in 1.2 the second request of a preview opens an exchange of
  # its own, and two exchanges with the same country must not yield two files
  # of one name.
  #
  # A message with neither part recorded still takes its number: the number is
  # the message's rank, not the file's.
  def files
    @files ||= begin
      counters = Hash.new(0)

      messages.flat_map do |exchange, event|
        prefix = test_id(exchange)
        type = event.event_type.start_with?('request') ? 'Req' : 'Res'
        rank = counters[[prefix, type]] += 1

        { 'H' => event.ebms_header, 'Ev' => event.regrep_body }.filter_map do |part, content|
          Entry.new(exchange:, name: "#{prefix}_#{part}#{type}#{rank}.xml", content:) if content.present?
        end
      end
    end
  end

  def messages
    carried = @exchanges.flat_map do |exchange|
      exchange.audit_events.select { it.event_type.in?(MESSAGE_TYPES) }.map { [exchange, it] }
    end

    without_echoes(carried).sort_by { |_, event| [event.occurred_at, event.id] }
  end

  # A gateway that is connected to nobody talks to itself, and France then
  # records each message twice, once sent and once received. Outside that loop
  # France never both sends and receives a message of the same kind in one
  # conversation: it is either the requester or the provider there. The message
  # identifier is deliberately not compared — nothing Domibus publishes
  # guarantees the one it gives a message on arrival matches the one at sending.
  def without_echoes(carried)
    sent = carried.filter_map { |_, event| kind(event) if event.event_type.in?(AuditEvent::SENT_BY_FRANCE) }

    carried.reject { |_, event| event.event_type.in?(AuditEvent::RECEIVED_BY_FRANCE) && kind(event).in?(sent) }
  end

  def kind(event) = event.event_type.delete_suffix('_sent').delete_suffix('_received')

  def first_exchange_with_files
    yielding = files.map(&:exchange).uniq

    @exchanges.find { it.in?(yielding) }
  end

  def test_id(exchange) = "#{exchange.requester_country_code}#{exchange.solicited_country_code}-#{@test_case}-#{@run}"
end
