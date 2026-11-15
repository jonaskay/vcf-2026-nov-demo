# frozen_string_literal: true

# Builds H0 (stock miniswen prompt split into the four always-on files) from the
# installed miniswen gem, then checks that harness_loader.rb renders it byte-identical
# to miniswen's own INSTANCE_TEMPLATE on a Linux sandbox.
#
#   ruby demo/tools/make_h0.rb demo/harnesses/h0

require "fileutils"
require "miniswen/agent"

out = ARGV.fetch(0) { abort "usage: ruby make_h0.rb <harness_dir>" }
tmpl = Miniswen::Agent::INSTANCE_TEMPLATE
marker = "\u0000INSTRUCTION\u0000"
text = format(tmpl, instruction: marker, system_information: "\u0000SYSINFO\u0000", macos_sed_note: "")

head, rest = text.split("## Command Execution Rules", 2)
guard, rest = rest.to_s.split("<system_information>", 2)
_, tools = rest.to_s.split("</system_information>", 2)
abort "template layout changed: a section marker is missing" if [ head, guard, tools ].any?(&:nil?)

files = {
  "system.md" => head.delete_prefix("Please solve this issue: #{marker}").strip,
  "guardrails.md" => "## Command Execution Rules#{guard}".strip,
  "memory.md" => "",
  "tool_guidance.md" => tools.strip
}
FileUtils.mkdir_p(File.join(out, "skills"))
files.each { |name, body| File.write(File.join(out, name), body.empty? ? "" : "#{body}\n") }
FileUtils.touch(File.join(out, "skills", ".keep"))

# Identity check with a realistic instruction and uname
ENV["LEMANS_HARNESS_DIR"] = File.expand_path(out)
load File.expand_path("../agents/harness_loader.rb", __dir__)
instruction = "Cards that sit idle should be flagged.\n\nAcceptance: see below.\n"
uname = "Linux 6.10.14-linuxkit #1 SMP aarch64"
stock = format(tmpl, instruction: instruction, system_information: uname, macos_sed_note: "")
rendered = HarnessPrompt.render(instruction, uname)

if rendered == stock
  puts "IDENTICAL: H0 renders byte-for-byte as stock miniswen (#{stock.size} chars)"
  files.each { |name, body| puts format("  %-17s %5d chars", name, body.size) }
else
  i = (0...[ stock.size, rendered.size ].min).find { |k| stock[k] != rendered[k] } || [ stock.size, rendered.size ].min
  warn "DIFFERENT at char #{i} (stock #{stock.size}, rendered #{rendered.size})"
  warn "  stock:    #{stock[[ i - 40, 0 ].max, 80].inspect}"
  warn "  rendered: #{rendered[[ i - 40, 0 ].max, 80].inspect}"
  exit 1
end
