# frozen_string_literal: true

# Checks that all relative markdown links in the project point to existing files.
# Skips auto-generated spec docs (docs/reference/specs/) which contain W3C-relative links.
#
# Usage:
#   ruby scripts/lint_links.rb
module LintLinks
  ROOT = File.expand_path('..', __dir__)

  def self.check
    errors = []

    md_files = Dir.glob([
      File.join(ROOT, '*.md'),
      File.join(ROOT, 'docs', '**', '*.md')
    ]) - Dir.glob(File.join(ROOT, 'docs', 'reference', 'specs', '*.md'))

    md_files.each do |file|
      dir = File.dirname(file)

      File.read(file).scan(/\[(?:[^\]]*)\]\(([^)]+)\)/).flatten.each do |link|
        next if link.start_with?('http://', 'https://', 'mailto:')

        path = link.split('#').first
        next if path.empty?

        target = File.expand_path(path, dir)
        next if File.exist?(target)

        relative = file.sub("#{ROOT}/", '')
        errors << "  #{relative}: #{link}"
      end
    end

    if errors.any?
      abort "Broken markdown links:\n#{errors.join("\n")}"
    else
      puts "All markdown links OK (#{md_files.size} files checked)"
    end
  end
end

LintLinks.check if __FILE__ == $PROGRAM_NAME
