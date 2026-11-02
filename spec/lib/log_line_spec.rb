require 'rails_helper'

RSpec.describe LogLine do
  # A line is read by whoever runs the deployment, whatever language the
  # browser whose request wrote it had chosen.
  it 'writes in the default locale under English' do
    line = I18n.with_locale(:en) { described_class.t('jobs.expire_exchanges_job.failed', id: 'e-1', error: 'boom') }

    expect(line).to eq(I18n.t('jobs.expire_exchanges_job.failed', id: 'e-1', error: 'boom', locale: :fr))
  end

  it 'composes in the default locale what a call it wraps translates' do
    expect(I18n.with_locale(:en) { described_class.speaking { I18n.locale } }).to eq(:fr)
  end
end
