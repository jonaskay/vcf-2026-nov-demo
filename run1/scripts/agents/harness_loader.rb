# frozen_string_literal: true

# Loaded into the miniswen CLI inside the sandbox via RUBYOPT=-r<this file>.
# Replaces miniswen's instance prompt (the first user message) with one
# rendered from the harness directory. The one-line system message stays stock.
#
# Render order mirrors miniswen's INSTANCE_TEMPLATE, so H0 renders byte-identical:
#   Please solve this issue: <instruction>
#   system.md, guardrails.md, <system_information>, memory.md, tool_guidance.md
#
# HarnessPrompt has no dependencies so tools/make_h0.rb can test it locally.

module HarnessPrompt
  ALWAYS_ON_BEFORE_SYSINFO = %w[system.md guardrails.md].freeze
  ALWAYS_ON_AFTER_SYSINFO = %w[memory.md tool_guidance.md].freeze
  STATUS_PATH = "/tmp/lemans-harness.status"

  module_function

  def dir = ENV.fetch("LEMANS_HARNESS_DIR", "/opt/harness")

  def part(name)
    path = File.join(dir, name)
    File.file?(path) ? File.read(path).strip : ""
  end

  def skill_files = Dir.glob(File.join(dir, "skills", "*", "SKILL.md")).sort

  # inline_skills: used only if the agent's jailed commands cannot read the
  # harness directory, so skills named in system.md stay reachable.
  def render(instruction, system_information, inline_skills: false)
    parts = [ "Please solve this issue: #{instruction}" ]
    parts += ALWAYS_ON_BEFORE_SYSINFO.map { |name| part(name) }
    parts << "<system_information>\n#{system_information}\n</system_information>"
    parts += ALWAYS_ON_AFTER_SYSINFO.map { |name| part(name) }
    if inline_skills
      skill_files.each { |file| parts << "## Skill file #{file}\n\n#{File.read(file).strip}" }
    end
    parts.reject(&:empty?).join("\n\n") + "\n"
  end
end

if File.basename($PROGRAM_NAME.to_s) == "miniswen" && ENV["LEMANS_HARNESS_DIR"]
  require "miniswen/agent"

  module HarnessedStart
    private

    def start(instruction)
      super
      stock = @messages[1][:content].to_s
      sysinfo = stock[%r{<system_information>\n(.*?)\n</system_information>}m, 1].to_s
      probe = execute("test -r #{HarnessPrompt.dir}/system.md && echo HARNESS_VISIBLE").output.to_s
      visible = probe.include?("HARNESS_VISIBLE")
      @messages[1] = { role: "user", content: HarnessPrompt.render(instruction, sysinfo, inline_skills: !visible) }
      File.write(HarnessPrompt::STATUS_PATH,
                 "loader=ok visible_to_commands=#{visible} skills=#{HarnessPrompt.skill_files.size} " \
                 "prompt_chars=#{@messages[1][:content].size}\n")
    rescue StandardError => e
      File.write(HarnessPrompt::STATUS_PATH, "loader=error #{e.class}: #{e.message}\n") rescue nil
      raise
    end
  end

  Miniswen::Agent.prepend(HarnessedStart)
end
