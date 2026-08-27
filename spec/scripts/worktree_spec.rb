require 'English'
require 'fileutils'
require 'tmpdir'

# The script is exercised as it ships — its own path, run as a process — in a
# throwaway git repository whose .env declares three high ports nothing listens
# on, so the shifts it retains are exactly +1, +2, +3.
RSpec.describe 'scripts/worktree.sh' do
  SCRIPT = File.expand_path('../../scripts/worktree.sh', __dir__)
  MAIN_PORTS = { 'PORT_OOTS_FRANCE' => 61_010, 'PORT_DOMIBUS' => 62_010, 'PORT_POSTGRES' => 63_010 }.freeze

  attr_reader :repository

  around do |example|
    Dir.mktmpdir('worktree-spec') do |directory|
      # The script resolves its root through the .git directory, which follows
      # symlinks: a TMPDIR reached through one would make every path mismatch.
      @repository = File.realpath(directory)
      example.run
    end
  end

  before do
    git('init', '--quiet', '--initial-branch=main')
    git('commit', '--quiet', '--allow-empty', '--message=Amorce')
    File.write(env_path, MAIN_PORTS.map { |name, port| "#{name}=#{port}\n" }.join)
  end

  def env_path(worktree = nil)
    worktree ? File.join(repository, '.worktrees', worktree, '.env') : File.join(repository, '.env')
  end

  def git(*arguments)
    settings = ['-c', 'user.name=Spec', '-c', 'user.email=spec@example.invalid', '-c', 'commit.gpgsign=false']
    return if system('git', *settings, *arguments, chdir: repository, out: File::NULL, err: File::NULL)

    raise "git #{arguments.join(' ')} a échoué"
  end

  def spawn_script(name)
    Process.spawn(SCRIPT, name, chdir: repository, out: File::NULL, err: File::NULL)
  end

  def run_script(name)
    Process.wait2(spawn_script(name)).last
  end

  def executable_path(command)
    ENV.fetch('PATH').split(File::PATH_SEPARATOR)
      .map { |directory| File.join(directory, command) }
      .find { |path| File.executable?(path) }
  end

  def ports_of(worktree)
    File.readlines(env_path(worktree)).filter_map { |line| line[/\APORT_[A-Z_0-9]*=(\d+)/, 1]&.to_i }
  end

  it 'gives distinct ports to three worktrees created at the same time' do
    names = %w[essai-a essai-b essai-c]
    statuses = names.map { |name| spawn_script(name) }.map { |pid| Process.wait2(pid).last }

    expect(statuses).to all(be_success)

    ports = names.flat_map { |name| ports_of(name) }
    expect(ports.size).to eq(9)
    expect(ports.uniq.size).to eq(9)
  end

  # What is asserted is that the next run goes through, not that the lock is free
  # at some instant: a killed shell leaves the `git worktree add` it had started
  # holding the descriptor it inherited, for as long as that command still runs.
  # Three delays rather than one, spread across the forty-odd milliseconds a run
  # takes, so that the kill lands inside the critical section whatever the
  # scheduling. The victim may therefore be killed or already done — but never
  # dead of its own accord, which would mean the run never reached the lock and
  # the example proved nothing.
  [0.001, 0.005, 0.02].each do |delay|
    it "leaves no lock blocking the next run when killed after #{delay} s" do
      victim = spawn_script('essai-tue')
      sleep delay
      Process.kill('KILL', victim)
      expect(Process.wait2(victim).last.exitstatus).to be_nil.or eq(0)

      started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      expect(run_script('essai-suivant')).to be_success
      # Far under the 60 s the script waits before giving up, and far over the
      # fraction of a second it needs: a lock nobody releases shows up here.
      expect(Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at).to be < 30
    end
  end

  # The degraded mode CLAUDE.md documents: without `flock` nothing is serialised,
  # and the script says which guarantee that costs instead of staying quiet. PATH
  # is rebuilt from the commands the script calls, that one excluded.
  it 'says what is lost, and still creates the worktree, when flock is missing' do
    without_flock = File.join(repository, 'chemin-sans-flock')
    FileUtils.mkdir_p(without_flock)
    %w[git sed grep cat mkdir dirname basename].each do |command|
      File.symlink(executable_path(command), File.join(without_flock, command))
    end

    output = IO.popen({ 'PATH' => without_flock }, [SCRIPT, 'essai-sans-verrou'],
      chdir: repository, err: %i[child out], &:read)

    expect($CHILD_STATUS).to be_success
    expect(output).to include('flock introuvable', 'même décalage de ports')
    expect(ports_of('essai-sans-verrou')).to eq(MAIN_PORTS.values.map { |port| port + 1 })
  end

  # Nothing is listening on the ports the first worktree reserved, so only the
  # .env it wrote can explain the second one avoiding them.
  it 'avoids the ports a worktree reserved without ever starting its stack' do
    expect(run_script('essai-premier')).to be_success
    expect(run_script('essai-second')).to be_success

    expect(ports_of('essai-premier').size).to eq(3)
    expect(ports_of('essai-premier') & ports_of('essai-second')).to be_empty
  end
end
