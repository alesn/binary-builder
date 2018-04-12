# encoding: utf-8
require_relative 'base'

class NginxRecipe < BaseRecipe
  def computed_options
    [
      '--prefix=/',
      '--error-log-path=stderr',
      '--with-http_ssl_module',
      '--with-http_realip_module',
      '--with-http_gunzip_module',
      '--with-http_gzip_static_module',
      '--with-http_auth_request_module',
      '--with-http_random_index_module',
      '--with-http_secure_link_module',
      '--with-http_stub_status_module',
      '--with-http_geoip_module',
      '--without-http_uwsgi_module',
      '--without-http_scgi_module',
      '--with-pcre',
      '--with-pcre-jit',
      '--with-cc-opt=-fPIE -pie',
      '--with-ld-opt=-fPIE -pie -z now',
    ]
  end

  # get files for geoip
  def cook
    install_apt('libgeoip-dev')
    super
  end

  def install
    return if installed?
    execute('install', [make_cmd, 'install', "DESTDIR=#{path}"])
  end

  def archive_files
    ["#{path}/*"]
  end

  def archive_path_name
    'nginx'
  end

  def setup_tar
    `mkdir -p #{path}/lib/`
    `cp -a /usr/lib/x86_64-linux-gnu/libGeoIP.so* #{path}/lib/`
    `rm -Rf #{path}/html/ #{path}/conf/*`
  end

  def url
    "http://nginx.org/download/nginx-#{version}.tar.gz"
  end

  private

  def install_apt(packages)
    STDOUT.print "Running 'install dependencies' for #{@name} #{@version}... "
    if run("sudo apt-get update && sudo apt-get -y install #{packages}")
      STDOUT.puts "OK"
    else
      raise "Failed to complete install dependencies task"
    end
  end

  def run(command)
    output = `#{command}`
    if $?.success?
      return true
    else
      STDOUT.puts "ERROR, output was:"
      STDOUT.puts output
      return false
    end
  end  
end
