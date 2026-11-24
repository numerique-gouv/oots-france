require 'rails_helper'

RSpec.describe TestFilesArchiveBuilder do
  def read_back(archive)
    entries = {}
    Zip::InputStream.open(StringIO.new(archive)) do |zip|
      while (entry = zip.get_next_entry)
        entries[entry.name] = zip.read
      end
    end
    entries
  end

  it 'writes each file under its name, byte for byte' do
    header = "<eb:Messaging>\n  <eb:UserMessage/>\n</eb:Messaging>"
    body = '<query:QueryRequest><rim:Slot name="Königreich"/></query:QueryRequest>'
    files = [
      TestFiles::Entry.new(exchange: nil, name: 'FRBE-TC06-01_HReq1.xml', content: header),
      TestFiles::Entry.new(exchange: nil, name: 'FRBE-TC06-01_EvReq1.xml', content: body),
    ]

    entries = read_back(described_class.new(files).build)

    expect(entries.keys).to eq(%w[FRBE-TC06-01_HReq1.xml FRBE-TC06-01_EvReq1.xml])
    expect(entries['FRBE-TC06-01_HReq1.xml']).to eq(header.b)
    expect(entries['FRBE-TC06-01_EvReq1.xml']).to eq(body.b)
  end
end
