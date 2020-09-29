# encoding: utf-8
require 'tmpdir'
require_relative 'yaml_presenter'

class ArchiveRecipe
  def initialize(recipe)
    @recipe = recipe
  end

  def compress!
    return if @recipe.archive_files.empty?

    @recipe.setup_tar if @recipe.respond_to? :setup_tar

    Dir.mktmpdir do |dir|
      archive_path = File.join(dir, @recipe.archive_path_name)
      FileUtils.mkdir_p(archive_path)

      @recipe.archive_files.each do |glob|
        `cp -r #{glob} #{archive_path}`
      end

      File.write("#{dir}/sources.yml", YAMLPresenter.new(@recipe).to_yaml)

      print "Running 'archive' for #{@recipe.name} #{@recipe.version}... "
      if @recipe.archive_filename.split('.').last == 'zip'
        output_dir = Dir.pwd

        Dir.chdir(dir) do
          `zip #{File.join(output_dir, @recipe.archive_filename)} -r .`
        end
      else
        # '/nginx' appended after #{dir} here is a workaround for nginx buildpack now 
        # expecting files directly in the root directory, not under 'nginx'
        `ls -A #{dir}/nginx | xargs tar czf #{@recipe.archive_filename} -C #{dir}/nginx`
      end
      puts 'OK'
    end
  end
end
