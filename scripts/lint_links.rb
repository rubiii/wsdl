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

    include_patterns = [
      File.join(ROOT, '{AGENTS,CHANGELOG,CODE_OF_CONDUCT,CONTRIBUTING,README,SECURITY}.md'),
      File.join(ROOT, 'docs', '**', '*.md')
    ]

    exclude_patterns = [
      File.join(ROOT, 'docs', 'reference', 'specs', '*.md'),
      File.join(ROOT, 'docs', 'adr', '0000-template.md')
    ]

    included = include_patterns.flat_map { |p| Dir.glob(p) }
    excluded = exclude_patterns.flat_map { |p| Dir.glob(p) }
    all_files = included - excluded

    all_files.each do |file|
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
      puts "All markdown links OK (#{all_files.size} files checked)"
    end
  end
end

LintLinks.check if __FILE__ == $PROGRAM_NAME
