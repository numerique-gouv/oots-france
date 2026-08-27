require 'rails_helper'

RSpec.describe SlotReading do
  # `require_content` names what is missing with a key rather than a sentence,
  # so nothing static ties the parsers to their wordings: `i18n-tasks` reads
  # neither side of a key it never sees written as a lookup.
  it 'says every key its parsers write' do
    written = Dir['app/parsers/**/*.rb']
      .flat_map { |path| File.read(path).scan(/'(parsers(?:\.[a-z_]+)+)'/) }
      .flatten.uniq

    expect_said(written)
  end

  # `R-EDM-ERR-C022` ties `PreviewLocation` to one severity and to no other, so a
  # message legitimately omits it. Absence is then an answer; emptiness is not,
  # and the two branches must not drift into each other — a reader that returned
  # nil on both would be laxer than optional, and nothing else would say so.
  describe 'a slot the message is allowed not to carry' do
    let(:reader) do
      Class.new {
        include SlotReading

        public :optional_slot_text
      }.new
    end

    def exception(slot)
      Nokogiri::XML(<<~XML).root
        <rs:Exception xmlns:rs="#{OotsNamespaces::NAMESPACES.fetch('rs')}"
                      xmlns:rim="#{OotsNamespaces::NAMESPACES.fetch('rim')}">#{slot}</rs:Exception>
      XML
    end

    def preview_slot(value)
      "<rim:Slot name='PreviewLocation'><rim:SlotValue><rim:Value>#{value}</rim:Value></rim:SlotValue></rim:Slot>"
    end

    it 'reads it when the message carries one' do
      read = reader.optional_slot_text('PreviewLocation', exception(preview_slot('https://example.si/espace')))

      expect(read).to eq('https://example.si/espace')
    end

    it 'names nothing, and refuses nothing, when the slot is absent' do
      expect(reader.optional_slot_text('PreviewLocation', exception(''))).to be_nil
    end

    # Present and empty is malformed, where absent is not: the message declared
    # the slot and then said nothing in it.
    it 'refuses a slot that is there and says nothing' do
      expect { reader.optional_slot_text('PreviewLocation', exception(preview_slot(''))) }
        .to raise_error(UnreadableMessageError)
    end
  end

  # `R-EDM-REQ-C073` requires nothing of an agent's address but the country, and
  # the reference fixtures all write it upper case: what reading a less careful
  # correspondent does is visible only from here.
  describe 'the country an agent declares' do
    let(:reader) do
      Class.new {
        include SlotReading

        public :agent_country
      }.new
    end

    def agent(country)
      inner = country.nil? ? '' : "<sdg:Address><sdg:AdminUnitLevel1>#{country}</sdg:AdminUnitLevel1></sdg:Address>"

      Nokogiri::XML(<<~XML).root
        <sdg:Agent xmlns:sdg="#{OotsNamespaces::NAMESPACES.fetch('sdg')}">#{inner}</sdg:Agent>
      XML
    end

    it 'upcases what a correspondent wrote in lower case' do
      expect(reader.agent_country(agent('fr'))).to eq('FR')
    end

    it 'keeps a code already written as one' do
      expect(reader.agent_country(agent('BE'))).to eq('BE')
    end

    # Stored as written, it would answer no filter by country — the log keeps
    # what it could read, and nothing it cannot read back.
    it 'drops what is not shaped like a country code' do
      expect(reader.agent_country(agent('France'))).to be_nil
    end

    it 'drops an address the message never carried' do
      expect(reader.agent_country(agent(nil))).to be_nil
    end
  end
end
