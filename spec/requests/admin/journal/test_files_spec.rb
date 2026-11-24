require 'rails_helper'

RSpec.describe 'Admin::Journal::TestFiles' do
  let(:conversation_id) { '5fe50e16-d6b8-4005-b5ec-0ab097f34319' }
  let(:belgium) { create(:exchange, conversation_id:, country_code: 'BE') }

  before do
    create(:audit_event, :with_ebms_header, :with_regrep_body, event_type: 'request_sent',
      exchange_id: belgium.exchange_id, conversation_id:)
  end

  def entry_names(archive)
    names = []
    Zip::InputStream.open(StringIO.new(archive)) do |zip|
      while (entry = zip.get_next_entry)
        names << entry.name
      end
    end
    names
  end

  describe 'GET /admin/journal/conversations/:conversation_id/test_files' do
    before { sign_in_as_administrator }

    it 'serves the files in a zip attachment named after the test' do
      get admin_journal_conversation_test_files_path(conversation_id, test_case: 'TC06', run: '01')

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq('application/zip')
      expect(response.headers['Content-Disposition']).to start_with('attachment').and include('FRBE-TC06-01.zip')
      expect(entry_names(response.body)).to eq(%w[FRBE-TC06-01_HReq1.xml FRBE-TC06-01_EvReq1.xml])
    end

    ['TC 06', '../TC06'].each do |test_case|
      it "serves no archive for the test case #{test_case.inspect}, and says why under the field" do
        get admin_journal_conversation_test_files_path(conversation_id, test_case:, run: '01')

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.media_type).to eq('text/html')
        field = response.parsed_body.at_css('input[name=test_case]')
        expect(field['value']).to eq(test_case)
        expect(response.parsed_body.at_css('#test_case-error').text)
          .to eq(I18n.t('activemodel.errors.models.test_run.attributes.test_case.format'))
      end
    end

    %w[1 001].each do |run|
      it "serves no archive for the run #{run.inspect}, and says why under the field" do
        get admin_journal_conversation_test_files_path(conversation_id, test_case: 'TC06', run:)

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.at_css('#run-error').text)
          .to eq(I18n.t('activemodel.errors.models.test_run.attributes.run.format'))
      end
    end

    it 'answers 404 for a conversation that yields no file' do
      empty = create(:exchange, country_code: 'BE')

      get admin_journal_conversation_test_files_path(empty.conversation_id)

      expect(response).to have_http_status(:not_found)
    end
  end

  it 'refuses an agent nobody named administrator, as the conversation page does' do
    sign_in

    get admin_journal_conversation_test_files_path(conversation_id)

    expect(response).to redirect_to(admin_restricted_access_path)
    expect(response.media_type).not_to eq('application/zip')
  end
end
