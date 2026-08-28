# The script is exercised as it ships — sourced by `sh`, the way the `web` and
# `worker` services source it — because sourcing is the whole of what it does:
# change the environment of the process that reads it. It is the entry point by
# which those two connect with the restricted role, so a regression in it would
# take the engine-level guarantee away with nothing to show for it.
RSpec.describe 'bin/database_role' do
  let(:script) { File.expand_path('../../bin/database_role', __dir__) }
  let(:owner) do
    { 'UTILISATEUR_BASE_DE_DONNEES' => 'proprietaire', 'MOT_DE_PASSE_BASE_DE_DONNEES' => 'secret_proprietaire' }
  end
  let(:application) do
    {
      'UTILISATEUR_APPLICATIF_BASE_DE_DONNEES' => 'applicatif',
      'MOT_DE_PASSE_APPLICATIF_BASE_DE_DONNEES' => 'secret_applicatif',
    }
  end

  # `unsetenv_others` so the suite's own environment cannot supply a variable an
  # example means to leave empty.
  def credentials_of(environment)
    read = %(printf '%s/%s' "$UTILISATEUR_BASE_DE_DONNEES" "$MOT_DE_PASSE_BASE_DE_DONNEES")
    IO.popen(environment, ['sh', '-c', ". #{script} && #{read}"], unsetenv_others: true, &:read)
  end

  it 'substitue le rôle applicatif quand ses deux variables sont là' do
    expect(credentials_of(owner.merge(application))).to eq('applicatif/secret_applicatif')
  end

  it 'laisse le propriétaire quand les deux sont vides, le dispositif étant facultatif' do
    expect(credentials_of(owner)).to eq('proprietaire/secret_proprietaire')
  end

  # Fail closed, and loudly elsewhere: the process keeps a working pair of
  # credentials rather than half of one, and `Settings.application_database_role`
  # refuses to let the server boot on a configuration only half filled in.
  %w[UTILISATEUR_APPLICATIF_BASE_DE_DONNEES MOT_DE_PASSE_APPLICATIF_BASE_DE_DONNEES].each do |alone|
    it "laisse le propriétaire quand #{alone} est seule" do
      expect(credentials_of(owner.merge(alone => application.fetch(alone))))
        .to eq('proprietaire/secret_proprietaire')
    end
  end
end
