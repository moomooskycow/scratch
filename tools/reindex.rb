#!/usr/bin/env ruby
# tools/reindex.rb - Regenerates index files for tenets and bindings
#
# Requirements:
# - Ruby 2.1+ (standard library compatibility)
# - Standard library: yaml, optparse, fileutils

require 'yaml'
require 'optparse'
require 'fileutils'

# Global error tracking
$errors = []
$warnings = []
$options = {
  strict: false,
  verbose: false
}

# Parse command line options
OptionParser.new do |opts|
  opts.banner = 'Usage: reindex.rb [options]'

  opts.on('--strict', 'Exit with error code on any error') do
    $options[:strict] = true
  end

  opts.on('--verbose', 'Show more detailed output') do
    $options[:verbose] = true
  end

  opts.on('-h', '--help', 'Show this help message') do
    puts opts
    exit
  end
end.parse!

# Helper methods for error reporting
def report_error(file, message)
  puts "ERROR: #{file}: #{message}"
  $errors << { file: file, message: message }
end

def report_warning(file, message)
  puts "WARNING: #{file}: #{message}" if $options[:verbose]
  $warnings << { file: file, message: message }
end

# Get the base docs path from environment variable or default
def get_docs_base_path
  base_path = ENV['LEYLINE_DOCS_PATH'] || 'docs'
  puts "Using docs base path: #{base_path}" if $options[:verbose]
  base_path
end

# Process tenets directory with enhanced error handling
def process_tenets_dir
  dir = "#{get_docs_base_path}/tenets"
  dir_base = dir.split('/').last
  entries = []

  # Get all markdown files except the index and glance files
  tenet_files = Dir.glob("#{dir}/*.md").reject { |f| f =~ /00-index\.md$/ || f =~ /glance\.md$/ }.sort
  puts "Processing #{tenet_files.size} tenet files..." if $options[:verbose]

  tenet_files.each do |file|
    content = File.read(file)

    # Check for YAML front-matter
    if content !~ /^---\n/
      report_error(file, 'No YAML front-matter found')
      next
    end

    # Extract front-matter and first paragraph after title using YAML format
    if content =~ /^---\n(.*?)\n---\s*#[^#]+(.*?)\n\n(.*?)(\n\n|\n#|$)/m
      # Parse YAML with explicit error handling
      yaml_content = Regexp.last_match(1)
      begin
        front_matter = YAML.safe_load(yaml_content)
      rescue StandardError => e
        report_error(file, "Invalid YAML in front-matter: #{e.message}")
        next
      end

      # Validate required fields for tenets
      required_fields = %w[id last_modified version]
      missing_fields = required_fields - front_matter.keys

      unless missing_fields.empty?
        report_error(file, "Missing required metadata fields: #{missing_fields.join(', ')}")
        next
      end

      Regexp.last_match(2).strip
      first_para = Regexp.last_match(3).strip.gsub(/\s+/, ' ')

      # Skip placeholder text that's enclosed in brackets
      if first_para =~ /^\[.*\]$/
        # Try to find the first real paragraph in the Core Belief/Rationale section
        if content =~ /## (Core Belief|Rationale)\s*\n\n(.*?)(\n\n|\n#|$)/m
          section_text = Regexp.last_match(2).strip.gsub(/\s+/, ' ')

          # Skip if this is also a placeholder
          if section_text =~ /^\[.*\]$/
            first_para = 'See document for details.'
            report_warning(file, 'Using placeholder text for summary')
          else
            first_para = section_text
          end
        else
          first_para = 'See document for details.'
          report_warning(file, 'Using placeholder text for summary - no Core Belief section found')
        end
      # This handles the non-bracketed placeholder case that might appear in templates
      elsif first_para.include?('Write a') && (first_para.include?('paragraph') || first_para.include?('explanation'))
        first_para = 'See document for details.'
        report_warning(file, 'Using placeholder text for summary - template text found')
      end

      # Truncate if too long
      summary = first_para.length > 150 ? "#{first_para[0, 147]}..." : first_para

      # Add to entries
      entries << {
        id: front_matter['id'] || File.basename(file, '.md'),
        summary: summary,
        version: front_matter['version']
      }
    else
      report_error(file, 'Could not parse file structure - expected YAML front-matter followed by title and content')
    end
  rescue StandardError => e
    report_error(file, "Failed to process file: #{e.message}")
  end

  # Generate index content
  index_content = "# #{dir_base.capitalize} Index\n\n"
  index_content += "This file contains an automatically generated list of all #{dir_base} with their one-line summaries.\n\n"

  # Add entries in a table
  if entries.any?
    index_content += "| ID | Version | Summary |\n"
    index_content += "|---|---|---|\n"
    entries.each do |entry|
      index_content += "| [#{entry[:id]}](./#{entry[:id]}.md) | #{entry[:version] || 'N/A'} | #{entry[:summary]} |\n"
    end
  else
    index_content += "_No #{dir_base} defined yet._\n"
    report_warning(dir, 'No valid tenet entries found for index generation')
  end

  # Ensure directory exists and write index file
  FileUtils.mkdir_p(dir)
  File.write("#{dir}/00-index.md", index_content)
  puts "Updated #{dir}/00-index.md with #{entries.size} entries"
end

# Process bindings with new directory structure
def process_bindings_dir
  dir = "#{get_docs_base_path}/bindings"

  # Check for misplaced files in the root directory
  misplaced_files = Dir.glob("#{dir}/*.md").reject { |f| f =~ /00-index\.md$/ || f =~ /glance\.md$/ }
  misplaced_files.each do |file|
    report_error(file, 'Misplaced binding file found in root directory')
    puts '       This file should be moved to either:' if $options[:verbose]
    puts "       - '#{dir}/core/' (if it's a core binding)" if $options[:verbose]
    puts "       - '#{dir}/categories/<category>/' (if it's a category-specific binding)" if $options[:verbose]
  end

  unless misplaced_files.empty?
    puts "Found #{misplaced_files.size} misplaced binding file(s) in root directory. These will be skipped."
  end

  # Initialize category collections
  core_entries = []
  category_entries = {}

  # 1. Process core bindings, excluding glance files
  core_files = Dir.glob("#{dir}/core/*.md").reject { |f| f =~ /glance\.md$/ }.sort
  puts "Processing #{core_files.size} core binding files..." if $options[:verbose]

  core_files.each do |file|
    entry = process_binding_file(file)
    if entry
      entry[:path] = "./core/#{File.basename(file)}"
      core_entries << entry
    end
  end

  # 2. Process category bindings
  # Define standard categories that should always be included
  standard_categories = %w[backend cli csharp frontend go rust typescript]

  # Initialize all standard categories
  standard_categories.each do |category|
    category_entries[category] = []
  end

  # Get all category directories for processing, adding any non-standard ones
  category_dirs = Dir.glob("#{dir}/categories/*").select { |f| File.directory?(f) }
  category_dirs.each do |category_dir|
    category_name = File.basename(category_dir)
    category_entries[category_name] ||= []
  end

  # Now process files in each category
  processed_files_count = 0
  category_dirs.each do |category_dir|
    category_name = File.basename(category_dir)

    # Look for markdown files in this category directory, excluding glance files
    binding_files = Dir.glob("#{category_dir}/*.md").reject { |f| f =~ /glance\.md$/ }.sort
    puts "Processing #{binding_files.size} binding files in category '#{category_name}'..." if $options[:verbose]

    # Process each binding file (if any)
    binding_files.each do |file|
      processed_files_count += 1
      entry = process_binding_file(file)
      if entry
        entry[:path] = "./categories/#{category_name}/#{File.basename(file)}"
        category_entries[category_name] << entry
      end
    end
  end

  # Log the categories we found
  puts "Found #{category_entries.keys.size} category directories: #{category_entries.keys.sort.join(', ')}"
  puts "#{category_entries.values.flatten.size} binding files processed successfully out of #{processed_files_count} total files"

  # Check if no valid bindings were found
  if core_entries.empty? && category_entries.values.flatten.empty?
    report_warning(dir, 'No valid binding entries found for index generation')
  end

  # Generate index content
  index_content = "# Bindings Index\n\n"
  index_content += "This file contains an automatically generated list of all bindings with their one-line summaries.\n\n"

  # Core bindings section
  index_content += "## Core Bindings\n\n"
  if core_entries.any?
    index_content += "| ID | Version | Summary |\n"
    index_content += "|---|---|---|\n"
    core_entries.each do |entry|
      index_content += "| [#{entry[:id]}](#{entry[:path]}) | #{entry[:version] || 'N/A'} | #{entry[:summary]} |\n"
    end
  else
    index_content += "_No core bindings defined yet._\n\n"
    report_warning("#{dir}/core", 'No valid core binding entries found')
  end

  # Category sections - process all standard categories in fixed order, then any additional ones
  (standard_categories + (category_entries.keys - standard_categories).sort).each do |category|
    entries = category_entries[category]

    # Use proper title case for category names
    category_title = category.capitalize
    if category =~ /^(ts|go)$/i
      category_title = category.upcase
    elsif category =~ /typescript/i
      category_title = 'TypeScript'
    end

    index_content += "\n## #{category_title} Bindings\n\n"

    if entries.any?
      index_content += "| ID | Version | Summary |\n"
      index_content += "|---|---|---|\n"
      entries.each do |entry|
        index_content += "| [#{entry[:id]}](#{entry[:path]}) | #{entry[:version] || 'N/A'} | #{entry[:summary]} |\n"
      end
    else
      # Handle empty category gracefully with an informative message
      # This ensures the section appears in the index but clearly indicates it's empty
      index_content += "_No #{category} bindings defined yet._\n"
      report_warning("#{dir}/categories/#{category}", 'No valid binding entries found for category')
    end
  end

  # Ensure directory exists and write index file
  FileUtils.mkdir_p(dir)
  File.write("#{dir}/00-index.md", index_content)
  puts "Updated #{dir}/00-index.md with #{core_entries.size} core entries and #{category_entries.values.flatten.size} category entries"
end

# Helper to process a single binding file and extract metadata
def process_binding_file(file)
  content = File.read(file)

  # Check for YAML front-matter
  if content !~ /^---\n/
    report_error(file, 'No YAML front-matter found')
    return nil
  end

  # Extract front-matter using YAML format
  if content =~ /^---\n(.*?)\n---\s*#[^#]+(.*?)\n\n(.*?)(\n\n|\n#|$)/m
    # Parse YAML with explicit error handling
    yaml_content = Regexp.last_match(1)
    begin
      front_matter = YAML.safe_load(yaml_content)
    rescue StandardError => e
      report_error(file, "Invalid YAML in front-matter: #{e.message}")
      return nil
    end

    # Validate required fields for bindings
    required_fields = %w[id last_modified derived_from enforced_by version]
    missing_fields = required_fields - front_matter.keys

    unless missing_fields.empty?
      report_error(file, "Missing required metadata fields: #{missing_fields.join(', ')}")
      return nil
    end

    Regexp.last_match(2).strip
    first_para = Regexp.last_match(3).strip.gsub(/\s+/, ' ')

    # Handle placeholders
    if first_para =~ /^\[.*\]$/
      if content =~ /## (Core Belief|Rationale)\s*\n\n(.*?)(\n\n|\n#|$)/m
        section_text = Regexp.last_match(2).strip.gsub(/\s+/, ' ')
        if section_text =~ /^\[.*\]$/
          first_para = 'See document for details.'
          report_warning(file, 'Using placeholder text for summary')
        else
          first_para = section_text
        end
      else
        first_para = 'See document for details.'
        report_warning(file, 'Using placeholder text for summary - no Rationale section found')
      end
    elsif first_para.include?('Write a') && (first_para.include?('paragraph') || first_para.include?('explanation'))
      first_para = 'See document for details.'
      report_warning(file, 'Using placeholder text for summary - template text found')
    end

    # Truncate if too long
    summary = first_para.length > 150 ? "#{first_para[0, 147]}..." : first_para

    # Return entry data
    {
      id: front_matter['id'] || File.basename(file, '.md'),
      summary: summary,
      version: front_matter['version']
    }
  else
    report_error(file, 'Could not parse file structure - expected YAML front-matter followed by title and content')
    nil
  end
rescue StandardError => e
  report_error(file, "Failed to process file: #{e.message}")
  nil
end

# Process each directory type
puts 'Starting index generation...' if $options[:verbose]
process_tenets_dir
process_bindings_dir

# Final error reporting
if !$errors.empty?
  puts "\n#{$errors.size} errors found during index generation:"
  $errors.each_with_index do |error, index|
    puts "  #{index + 1}. #{error[:file]}: #{error[:message]}"
  end

  puts "\nIndex generation completed with errors"
  exit 1 if $options[:strict]
else
  puts "\nIndex generation completed successfully"
end

if !$warnings.empty? && $options[:verbose]
  puts "\n#{$warnings.size} warnings found:"
  $warnings.each_with_index do |warning, index|
    puts "  #{index + 1}. #{warning[:file]}: #{warning[:message]}"
  end
end
