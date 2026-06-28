#!/usr/bin/env ruby
# Script to filter bindings based on repository languages and contexts

require 'yaml'
require 'json'
require 'fileutils'

# Load the detected repo context
repo_context = JSON.parse(File.read('repo-context.json'))
languages = repo_context['languages']
contexts = repo_context['contexts']

puts "Repository languages: #{languages.join(', ')}"
puts "Repository contexts: #{contexts.join(', ')}"

# Create temp directory for filtered bindings
FileUtils.mkdir_p('filtered_bindings')

# Copy index file
if File.exist?('_leyline/docs/bindings/00-index.md')
  FileUtils.cp('_leyline/docs/bindings/00-index.md', 'filtered_bindings/00-index.md')
end

# Process all binding files
binding_files = Dir.glob('_leyline/docs/bindings/*.md').reject { |f| f =~ /00-index\.md$/ }
binding_files.each do |file|
  content = File.read(file)

  # Default to include if no applies_to field
  include_binding = true

  # Extract front-matter
  if content =~ /^---\n(.*?)\n---/m
    yaml_content = $1
    begin
      front_matter = YAML.safe_load(yaml_content)

      # Check applies_to field if present
      if front_matter && front_matter.key?('applies_to')
        applies_to = front_matter['applies_to']

        # If applies_to contains 'all', always include
        if applies_to.include?('all')
          include_binding = true
        else
          # Check if any language or context matches
          language_match = (applies_to & languages).any?
          context_match = (applies_to & contexts).any?

          # Include if either language or context matches
          include_binding = language_match || context_match
        end
      else
        # Use filename convention as fallback
        basename = File.basename(file)
        if basename =~ /^(ts|js|go|rust|py|java|cs|rb)-/
          prefix = $1
          language_map = {
            'ts' => 'typescript', 'js' => 'javascript', 'go' => 'go',
            'rust' => 'rust', 'py' => 'python', 'java' => 'java',
            'cs' => 'csharp', 'rb' => 'ruby'
          }
          # Check if language prefix matches any repo language
          include_binding = languages.include?(language_map[prefix]) || languages.include?('all')
        end
      end
    rescue => e
      puts "Warning: Error parsing YAML in #{file}: #{e.message}"
      # Default to include if parse error
      include_binding = true
    end
  end

  if include_binding
    dest_file = "filtered_bindings/#{File.basename(file)}"
    FileUtils.cp(file, dest_file)
    puts "Including binding: #{File.basename(file)}"
  else
    puts "Excluding binding: #{File.basename(file)} (not applicable to this repository)"
  end
end

# Report summary
total_bindings = binding_files.count
included_bindings = Dir.glob('filtered_bindings/*.md').reject { |f| f =~ /00-index\.md$/ }.count
puts "Filtered #{included_bindings} out of #{total_bindings} bindings based on repository context"
