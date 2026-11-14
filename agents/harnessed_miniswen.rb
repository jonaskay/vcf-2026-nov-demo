# frozen_string_literal: true

# harnessed-miniswen: the stock miniswen-installed agent, plus an editable harness.
#
#   HARNESS_DIR=demo/harnesses/h0 \
#   lemans -r ../demo/agents/harnessed_miniswen.rb run --agent harnessed-miniswen --backend docker ...
#
# One harness per lemans process (HARNESS_DIR is read once); run one process per candidate.
#
# install: uploads the harness to /opt/harness (outside /app, so agent.patch stays clean)
#          and harness_loader.rb to /opt/lemans-harness/.
# run:     miniswen starts with RUBYOPT=-r<loader>, which re-renders the instance prompt.
# after:   prints the loader's status line, so a silent fallback to stock prompts is visible.

require "shellwords"
require "tempfile"
require "tmpdir"

class HarnessedMiniswen < Lemans::Agents.lookup("miniswen-installed")
  NAME = "harnessed-miniswen"
  HARNESS_REMOTE = "/opt/harness"
  LOADER_REMOTE = "/opt/lemans-harness/loader.rb"
  LOADER_LOCAL = File.expand_path("harness_loader.rb", __dir__)
  STATUS_REMOTE = "/tmp/lemans-harness.status"

  def initialize(...)
    super
    dir = ENV["HARNESS_DIR"].to_s
    raise Lemans::ConfigError, "#{NAME}: export HARNESS_DIR=<harness dir>" if dir.empty?

    @harness_dir = File.expand_path(dir)
    return if File.file?(File.join(@harness_dir, "system.md"))

    raise Lemans::ConfigError, "#{NAME}: no system.md in #{@harness_dir}"
  end

  def install(task, environment)
    super
    Dir.mktmpdir do |tmp|
      tarball = File.join(tmp, "harness.tgz")
      # COPYFILE_DISABLE keeps macOS tar from adding ._ AppleDouble files
      system({ "COPYFILE_DISABLE" => "1" }, "tar", "--exclude", ".DS_Store", "-czf", tarball,
             "-C", @harness_dir, ".", exception: true)
      environment.upload(tarball, "/tmp/lemans-harness.tgz")
    end
    environment.upload(LOADER_LOCAL, "/tmp/lemans-harness-loader.rb")
    environment.exec!(<<~SH.tr("\n", " "), timeout: 60)
      set -e;
      rm -rf #{HARNESS_REMOTE} && mkdir -p #{HARNESS_REMOTE} #{File.dirname(LOADER_REMOTE)};
      tar -xzf /tmp/lemans-harness.tgz -C #{HARNESS_REMOTE};
      mv /tmp/lemans-harness-loader.rb #{LOADER_REMOTE};
      chmod -R a+rX #{HARNESS_REMOTE} #{File.dirname(LOADER_REMOTE)};
      rm -f /tmp/lemans-harness.tgz #{STATUS_REMOTE}
    SH
  end

  private

  def provider_env(environment)
    super.merge("RUBYOPT" => "-r#{LOADER_REMOTE}", "LEMANS_HARNESS_DIR" => HARNESS_REMOTE)
  end

  def obtain_result(task, environment, history)
    super
  ensure
    report_harness_status(task, environment)
  end

  def report_harness_status(task, environment)
    status = Tempfile.create(%w[harness .status]) do |file|
      environment.download(STATUS_REMOTE, file.path)
      File.read(file.path).strip
    end
    warn "#{NAME} [#{task_label(task)}] #{File.basename(@harness_dir)}: #{status}"
  rescue StandardError
    warn "#{NAME} [#{task_label(task)}] #{File.basename(@harness_dir)}: NO STATUS FILE, the loader did not run (stock prompts used?)"
  end

  def task_label(task) = task.respond_to?(:name) ? task.name : task.to_s
end

Lemans::Agents.register(HarnessedMiniswen::NAME, HarnessedMiniswen)
