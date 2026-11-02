require 'rails_helper'

RSpec.describe ApplicationJob do
  let(:job_class) do
    stub_const('LocaleProbeJob', Class.new(described_class) do
      cattr_accessor :seen
      def perform = self.class.seen = I18n.locale
    end)
  end

  # ActiveJob serializes the locale of the request that enqueues a job, and a
  # page read in English must not have its job answer a correspondent in it.
  it 'performs in the default locale whatever language enqueued it' do
    serialized = I18n.with_locale(:en) { job_class.new.serialize }
    expect(serialized['locale']).to eq('en')

    ActiveJob::Base.execute(serialized)

    expect(job_class.seen).to eq(:fr)
  end
end
