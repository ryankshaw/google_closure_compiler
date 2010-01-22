require "rexml/document"
require "yaml"
require 'zlib'
require "yui/compressor"

require "app/helpers/google_closure_helper" 

require 'google_closure_compiler/javascript'
require 'google_closure_compiler/stylesheet'

raise "GoogleClosureCompiler only Supports Rails <= 2.1.x" unless Rails.version >= "2.1"
ActionView::Base.send :include, GoogleClosureHelper

# Adapted from Smurf plugin http://github.com/thumblemonks/smurf/
# Supports Rails <= 2.1.x
module ActionView::Helpers::AssetTagHelper
private
  def join_asset_file_contents_with_compilation(files)
    content = join_asset_file_contents_without_compilation(files)
    if !files.grep(%r[/javascripts]).empty?
      content = GoogleClosureCompiler::Javascript.new(content).compiled
    elsif !files.grep(%r[/stylesheets]).empty?
      content = GoogleClosureCompiler::Stylesheet.new(content).compressed
    end
    content
  end
  alias_method_chain :join_asset_file_contents, :compilation
  
  # this helps the NginxHttpGzipStaticModule do it's thing.
  # from it's website:
  # Before serving a file from disk to a gzip-enabled client, this module will look 
  # for a precompressed file in the same location that ends in ".gz". The purpose 
  # is to avoid compressing the same file each time it is requested. 
  # see http://wiki.nginx.org/NginxHttpGzipStaticModule
  def write_asset_file_contents_with_create_static_gziped_files(joined_asset_path, asset_paths)
    FileUtils.mkdir_p(File.dirname(joined_asset_path))
    contents = join_asset_file_contents(asset_paths)
    File.open(joined_asset_path, "w+") { |cache| cache.write(contents) }
    
    zip_name = "#{joined_asset_path}.gz"
    Zlib::GzipWriter.open(zip_name, Zlib::BEST_COMPRESSION) {|f| f.write(contents) }
    # Set mtime to the latest of the combined files to allow for
    # consistent ETag without a shared filesystem.
    mt = asset_paths.map { |p| File.mtime(asset_file_path(p)) }.max
    File.utime(mt, mt, joined_asset_path, zip_name)
  end
  alias_method_chain :write_asset_file_contents, :create_static_gziped_files
  
  
  
end # ActionView::Helpers::AssetTagHelper

module GoogleClosureCompiler
  class << self
    CONFIG = YAML.load_file(File.join(RAILS_ROOT, 'config', 'google_closure_compiler.yml'))[RAILS_ENV] || {}
    
    def compiler_application_path
      CONFIG['compiler_application_path'] || File.join(File.dirname(__FILE__), '..', 'bin', 'compiler.jar')
    end
  
    def compilation_level
      CONFIG['compilation_level'] || 'SIMPLE_OPTIMIZATIONS'
    end
    
    def java_path
      CONFIG['java_path'] || 'java'
    end
    
    def python_path
      CONFIG['python_path'] || 'python'
    end
    
    def closure_library_path
      CONFIG['closure_library_path'] || 'closure'
    end
    
    def closure_library_full_path
      File.join(RAILS_ROOT, 'public', 'javascripts', closure_library_path)
    end
  end
end