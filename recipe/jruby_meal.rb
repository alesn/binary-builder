# encoding: utf-8
require_relative 'ant'
require_relative 'jruby'
require_relative 'maven'
require_relative 'openjdk7'

class JRubyMeal
  attr_reader :name, :version

  def initialize(name, version, options = {})
    @name    = name
    @version = version
    @options = options
  end

  def cook
    # NOTE: We compile against OpenJDK7 because trusty does not support
    # OpenJDK8. Unable to use java-buildpack OpenJDK8 because it only contains
    # the JRE, not the JDK.
    # https://www.pivotaltracker.com/story/show/106836266
    # puts `apt-get install software-properties-common -y`
    # puts `add-apt-repository ppa:openjdk-r/ppa -y`
    # puts `apt-get update`
    # puts `apt-get install openjdk-8-jdk -y`

    puts `mkdir /opt/java`
    puts `wget https://java-buildpack.cloudfoundry.org/openjdk-jdk/trusty/x86_64/openjdk-1.8.0_111.tar.gz -O /opt/java/openjdk-1.8-jdk.tar.gz`
    #puts `wget https://java-buildpack.cloudfoundry.org/openjdk-jdk/trusty/x86_64/openjdk-1.8.0_91-unlimited-crypto.tar.gz -O /opt/java/openjdk-1.8-jdk.tar.gz`
    Dir.chdir('/opt/java') do
      puts `tar xvf openjdk-1.8-jdk.tar.gz`
    end

    #openjdk.cook
    ENV['JAVA_HOME'] = '/opt/java'
    ENV['PATH'] = "#{ENV['PATH']}:/opt/java/bin"

    ant.cook
    ant.activate

    maven.cook
    maven.activate

    jruby.cook
  end

  def url
    jruby.url
  end

  def archive_files
    jruby.archive_files
  end

  def archive_path_name
    jruby.archive_path_name
  end

  def archive_filename
    jruby.archive_filename
  end

  private

  def files_hashs
    ant.send(:files_hashs) +
      maven.send(:files_hashs) +
      jruby.send(:files_hashs)
  end

  def jruby
    @jruby ||= JRubyRecipe.new(@name, @version, @options)
  end

  def openjdk
    @openjdk ||= OpenJDK8Recipe.new('openjdk', '8')
  end

  def maven
    @maven ||= MavenRecipe.new('maven', '3.3.9', md5: '030ce5b3d369f01aca6249b694d4ce03')
  end

  def ant
    @ant ||= AntRecipe.new('ant', '1.9.7', md5: 'a2fd9458c76700b7be51ef12f07d4bb1')
  end
end
