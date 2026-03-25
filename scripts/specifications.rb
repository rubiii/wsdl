# frozen_string_literal: true

require 'digest'
require 'net/http'
require 'nokogiri'
require 'uri'
require 'yaml'

# Downloads W3C/OASIS specification documents, converts HTML to markdown,
# and stores them locally for agent and developer reference.
#
# Usage:
#   ruby scripts/specifications.rb check              # report freshness status
#   ruby scripts/specifications.rb update              # download and convert all specs
#   ruby scripts/specifications.rb update --force      # reconvert even if source unchanged
module Specifications
  MANIFEST_PATH    = File.expand_path('../docs/reference/specs/manifest.yml', __dir__)
  SPECS_DIR        = File.dirname(MANIFEST_PATH)
  PROGRESS_WIDTH   = 72
  MAX_REDIRECTS    = 5
  OPEN_TIMEOUT     = 15
  READ_TIMEOUT     = 30

  # Elements whose content is passed through recursively without
  # any markdown wrapper. Unrecognized elements also fall through
  # here so content is never silently dropped.
  PASSTHROUGH_ELEMENTS = Set.new(%w[
    div section article main span li td th dd dt
    tbody thead tfoot tr figure figcaption aside
    header footer sup sub small
  ]).freeze

  # ── Public API ──────────────────────────────────────────────────────

  # Print a freshness report for every spec in the manifest.
  # Uses If-Modified-Since to avoid downloading unchanged content.
  def self.check
    manifest = load_manifest
    results = each_spec_with_progress(manifest) do |_key, spec|
      check_one(spec, spec_path(spec))
    end

    print_report(results)
    results.all? { |_, status, _| status == :up_to_date }
  end

  # Download, convert, and save every spec. Updates manifest with metadata.
  # When +force+ is true, reconverts even if the source HTML hasn't changed.
  def self.update(force: false)
    manifest = load_manifest
    results = each_spec_with_progress(manifest) do |key, spec|
      update_one(key, spec, manifest, force:)
    end

    save_manifest(manifest)
    print_report(results)
  end

  # ── Iteration ──────────────────────────────────────────────────────

  def self.each_spec_with_progress(manifest)
    total = manifest.size
    manifest.each_with_index.map do |(key, spec), index|
      progress = "  [#{index + 1}/#{total}] #{spec['name']}..."
      $stdout.write "\r#{progress.ljust(PROGRESS_WIDTH)}"
      $stdout.flush
      status = yield key, spec
      [spec['name'], status, spec_path(spec)]
    end
  ensure
    $stdout.write "\r#{' ' * PROGRESS_WIDTH}\r"
  end

  def self.spec_path(spec)
    File.join(SPECS_DIR, spec['file'])
  end

  # ── Check / Update ─────────────────────────────────────────────────

  def self.check_one(spec, local_path)
    return :missing unless File.exist?(local_path)

    stored_lm = spec['last_modified']
    return :unknown unless stored_lm

    html, _lm, code = fetch(spec['url'], if_modified_since: stored_lm)

    case code
    when 304 then :up_to_date
    when 200
      sha = Digest::SHA256.hexdigest(html)
      sha == spec['sha256'] ? :up_to_date : :stale
    else
      :error
    end
  rescue StandardError => e
    warn "  [error] #{spec['name']}: #{e.message}"
    :error
  end

  # NOTE: mutates +manifest[key]+ in place with sha256/last_modified/updated_at.
  def self.update_one(key, spec, manifest, force: false)
    html, last_modified, code = fetch(spec['url'])

    unless code == 200
      warn "  [error] #{spec['name']}: HTTP #{code}"
      return :error
    end

    sha = Digest::SHA256.hexdigest(html)
    return :unchanged if !force && sha == spec['sha256'] && File.exist?(spec_path(spec))

    markdown = convert(html, spec['url'], copyright: spec['copyright'])
    File.write(spec_path(spec), markdown)

    manifest[key]['sha256']        = sha
    manifest[key]['last_modified'] = last_modified
    manifest[key]['updated_at']    = Time.now.utc.strftime('%Y-%m-%d')

    :updated
  rescue StandardError => e
    warn "  [error] #{spec['name']}: #{e.message}"
    :error
  end

  # ── HTTP ────────────────────────────────────────────────────────────

  def self.fetch(url, if_modified_since: nil)
    uri = URI(url)
    redirects = 0

    loop do
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = (uri.scheme == 'https')
      http.open_timeout = OPEN_TIMEOUT
      http.read_timeout = READ_TIMEOUT

      request = Net::HTTP::Get.new(uri)
      request['Accept'] = 'text/html'
      request['If-Modified-Since'] = if_modified_since if if_modified_since

      response = http.request(request)

      case response
      when Net::HTTPNotModified
        return [nil, if_modified_since, 304]
      when Net::HTTPRedirection
        redirects += 1
        raise "too many redirects (#{MAX_REDIRECTS})" if redirects > MAX_REDIRECTS

        uri = URI(response['location'])
      when Net::HTTPSuccess
        return [response.body, response['last-modified'], response.code.to_i]
      else
        return [nil, nil, response.code.to_i]
      end
    end
  end

  # ── HTML → Markdown conversion ──────────────────────────────────────

  def self.convert(html, source_url, copyright: nil)
    doc = Nokogiri::HTML(html)
    strip_non_content!(doc)

    body = doc.at_css('body') || doc.root
    content = convert_node(body).join

    content = clean_up_whitespace(content)
    build_document(content, source_url, copyright)
  end

  def self.strip_non_content!(doc)
    doc.css('script, style, link, meta, nav, .navbar, .fixedbar, .head details').each(&:remove)
    doc.css('a > img[alt="W3C"]').each { |img| img.parent.remove }
  end

  def self.clean_up_whitespace(content)
    content
      .gsub(/[ \t]+$/, '')                   # remove trailing whitespace on lines
      .gsub(/^[ \t]+(?=\S)/) { |ws|          # collapse leading whitespace in non-code blocks
        ws.include?("\t") ? ws : (ws.length > 4 ? '' : ws)
      }
      .gsub(/\]\(([^)]*)\)\[/, "](\\1)\n[")  # split concatenated TOC links onto separate lines
      .gsub(/^Copyright[©®\s].*$/i, '')      # strip broken copyright lines (proper notice in header)
      .gsub(/\n{3,}/, "\n\n")                # collapse multiple blank lines to one (must be last)
      .strip
  end

  def self.build_document(content, source_url, copyright)
    copyright_line = copyright ? "\n<!-- #{copyright} -->" : ''
    header = <<~HEADER
      <!-- Auto-generated by scripts/specifications.rb — do not edit manually -->
      <!-- Source: #{source_url} -->#{copyright_line}

    HEADER

    "#{header}#{content}\n"
  end

  # ── Node conversion ─────────────────────────────────────────────────

  def self.convert_node(node)
    result = []
    node.children.each { |child| convert_child(child, result) }
    result
  end

  def self.convert_child(child, result)
    case child.name
    when 'text'       then convert_text(child, result)
    when /\Ah[1-6]\z/ then convert_heading(child, result)
    when 'p'          then convert_paragraph(child, result)
    when 'pre'        then convert_preformatted(child, result)
    when 'code'       then result << "`#{child.text}`"
    when 'strong', 'b' then convert_inline(child, result, '**')
    when 'em', 'i'     then convert_inline(child, result, '*')
    when 'a'          then convert_link(child, result)
    when 'ul'         then convert_list(child, result, ordered: false)
    when 'ol'         then convert_list(child, result, ordered: true)
    when 'dl'         then convert_definition_list(child, result)
    when 'table'      then result << convert_table(child)
    when 'blockquote' then convert_blockquote(child, result)
    when 'br'         then result << "\n"
    when 'hr'         then result << "\n\n---\n\n"
    when 'img'        then convert_image(child, result)
    else
      # Pass through recognized container elements and any unrecognized
      # elements so content is never silently dropped.
      result.concat(convert_node(child))
    end
  end

  def self.convert_text(child, result)
    if child.ancestors('pre').any?
      result << child.text
    else
      collapsed = child.text.gsub(/[ \t]*\n[ \t]*/, ' ').gsub(/[ \t]{2,}/, ' ')
      result << collapsed unless collapsed.strip.empty? && result.last&.end_with?("\n")
    end
  end

  def self.convert_heading(child, result)
    level = child.name[1].to_i
    prefix = '#' * level
    anchor = child['id'] || child.at_css('[id]')&.[]('id')
    heading_text = child_text(child).strip
    return if heading_text.empty?

    id_suffix = anchor ? " {##{anchor}}" : ''
    result << "\n\n#{prefix} #{heading_text}#{id_suffix}\n\n"
  end

  def self.convert_paragraph(child, result)
    text = convert_node(child).join.strip
    result << "\n\n#{text}\n" unless text.empty?
  end

  def self.convert_preformatted(child, result)
    result << "\n\n```\n#{child.text.rstrip}\n```\n\n"
  end

  def self.convert_inline(child, result, marker)
    text = convert_node(child).join.strip
    result << "#{marker}#{text}#{marker}" unless text.empty?
  end

  def self.convert_link(child, result)
    text = convert_node(child).join.strip
    href = child['href']
    result << if href && !text.empty? && href != text
      "[#{text}](#{href})"
    else
      text
    end
  end

  def self.convert_list(child, result, ordered:)
    selector = '> li'
    items = if ordered
      child.css(selector).each_with_index.map do |li, i|
        "#{i + 1}. #{convert_node(li).join.strip}"
      end
    else
      child.css(selector).map { |li| "- #{convert_node(li).join.strip}" }
    end
    result << "\n\n#{items.join("\n")}\n" unless items.empty?
  end

  def self.convert_definition_list(child, result)
    child.children.each do |dt_dd|
      text = convert_node(dt_dd).join.strip
      next if text.empty?

      case dt_dd.name
      when 'dt' then result << "\n\n**#{text}**\n"
      when 'dd' then result << ": #{text}\n"
      end
    end
  end

  def self.convert_blockquote(child, result)
    text = convert_node(child).join.strip
    return if text.empty?

    quoted = text.lines.map { |l| "> #{l}" }.join
    result << "\n\n#{quoted}\n"
  end

  def self.convert_image(child, result)
    alt = child['alt']
    result << "[Image: #{alt}]" if alt && !alt.empty?
  end

  def self.convert_table(table)
    rows = table.css('tr').map do |tr|
      tr.css('th, td').map { |cell| convert_node(cell).join.strip.gsub('|', '\\|') }
    end

    return '' if rows.empty?

    max_cols = rows.map(&:size).max
    rows.each { |r| r.fill('', r.size...max_cols) }

    widths = (0...max_cols).map do |col|
      rows.map { |r| r[col].length }.max.clamp(3, 60)
    end

    lines = []
    rows.each_with_index do |row, i|
      cells = row.each_with_index.map { |cell, j| cell.ljust(widths[j]) }
      lines << "| #{cells.join(' | ')} |"
      if i.zero?
        separators = widths.map { |w| '-' * w }
        lines << "| #{separators.join(' | ')} |"
      end
    end

    "\n\n#{lines.join("\n")}\n\n"
  end

  def self.child_text(node)
    node.children.map { |c| c.text? ? c.text : child_text(c) }.join
  end

  # ── Manifest I/O ────────────────────────────────────────────────────

  def self.load_manifest
    YAML.safe_load_file(MANIFEST_PATH, permitted_classes: [Date, Time])
  end

  def self.save_manifest(manifest)
    header = File.readlines(MANIFEST_PATH)
      .take_while { |l| l.start_with?('#') || l.strip.empty? }
      .join

    yaml = manifest.to_yaml.sub(/\A---\n/, '')
    File.write(MANIFEST_PATH, "#{header}#{yaml}")
  rescue StandardError => e
    warn "  [error] Failed to save manifest: #{e.message}"
  end

  # ── Reporting ───────────────────────────────────────────────────────

  STATUS_LABELS = {
    up_to_date: 'UP TO DATE',
    unchanged: 'UNCHANGED',
    updated: 'UPDATED',
    missing: 'MISSING',
    stale: 'STALE',
    unknown: 'UNKNOWN',
    error: 'ERROR'
  }.freeze

  STATUS_COLORS = {
    up_to_date: "\e[32m",
    unchanged: "\e[32m",
    updated: "\e[33m",
    missing: "\e[31m",
    stale: "\e[31m",
    unknown: "\e[33m",
    error: "\e[31m"
  }.freeze

  def self.print_report(results)
    puts
    results.each do |name, status, _path|
      color = STATUS_COLORS[status] || ''
      label = STATUS_LABELS[status] || status.to_s.upcase
      puts format("  #{color}%-12s\e[0m %s", label, name)
    end
    puts
  end

  private_class_method :each_spec_with_progress, :spec_path,
                       :check_one, :update_one, :fetch,
                       :convert, :strip_non_content!, :clean_up_whitespace, :build_document,
                       :convert_node, :convert_child,
                       :convert_text, :convert_heading, :convert_paragraph,
                       :convert_preformatted, :convert_inline, :convert_link,
                       :convert_list, :convert_definition_list, :convert_blockquote,
                       :convert_image, :convert_table, :child_text,
                       :load_manifest, :save_manifest, :print_report
end

# CLI entrypoint
if __FILE__ == $PROGRAM_NAME
  case ARGV[0]
  when 'check'
    exit(Specifications.check ? 0 : 1)
  when 'update'
    Specifications.update(force: ARGV.include?('--force'))
  else
    warn "Usage: ruby #{$PROGRAM_NAME} [check|update [--force]]"
    exit 1
  end
end
