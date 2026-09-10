require 'rails_helper'

# `config.after_initialize` registers through `ActiveSupport.on_load`, which
# runs the block at once when its hook has already fired — as it has, the
# application having booted before this file was read. Loading the initializer
# therefore performs the check inside the example.
RSpec.describe 'config/initializers/verify_settings.rb' do
  # `exe/good_job` raises this flag before the CLI loads the environment, and it
  # is the whole of what tells the worker from the console, the Rake task and
  # this suite.
  def boot(within_exe, environment)
    allow(GoodJob::CLI).to receive(:within_exe?).and_return(within_exe)

    with_environment(environment) { load Rails.root.join('config/initializers/verify_settings.rb') }
  end

  it 'starts the worker on a configuration the contract is content with' do
    expect { boot(true, complete_environment) }.not_to raise_error
  end

  # Named, and not merely refused: the worker is restarted by whoever reads this
  # message, and a refusal that does not say what to fill in costs a deployment
  # per variable.
  it 'refuses to start the worker on a missing variable, and names it' do
    expect { boot(true, complete_environment.merge('URL_BASE_DOMIBUS' => nil)) }
      .to raise_error(ConfigurationError, /URL_BASE_DOMIBUS/)
  end

  # The switch decides which set is mandatory, so reading it is how the contract
  # composes one — and an unreadable switch stops the worker here rather than at
  # the first sweep of the exchanges that have expired.
  it 'refuses to start the worker on a timeout switch it cannot read' do
    expect { boot(true, complete_environment.merge('AVEC_DELAI_EXPIRATION' => 'peut-être')) }
      .to raise_error(ConfigurationError, /AVEC_DELAI_EXPIRATION/)
  end

  # The guarantee that the Rake task rendering the messages for the Schematron
  # validation, `rails console`, `rails db:migrate` and this suite still boot on
  # a machine that has no gateway configured at all.
  it 'checks nothing in a process that is not the worker' do
    expect { boot(false, Settings::REQUIRED.index_with { nil }) }.not_to raise_error
  end
end
