# encoding: utf-8
require_relative 'php_common'

class Php7Recipe < BaseRecipe
  def configure_options
    [
      '--disable-static',
      '--enable-shared',
      '--enable-ftp=shared',
      '--enable-sockets=shared',
      '--enable-soap=shared',
      '--enable-fileinfo=shared',
      '--enable-bcmath',
      '--enable-calendar',
      '--enable-intl',
      '--with-kerberos',
      '--enable-zip=shared',
      '--with-bz2=shared',
      '--with-curl=shared',
      '--enable-dba=shared',
      '--with-cdb',
      '--with-gdbm',
      '--with-mcrypt=shared',
      '--with-mysqli=shared',
      '--enable-pdo=shared',
      '--with-pdo-sqlite=shared,/usr',
      '--with-pdo-mysql=shared,mysqlnd',
      '--with-gd=shared',
      '--with-jpeg-dir=/usr',
      '--with-freetype-dir=/usr',
      '--enable-gd-native-ttf',
      '--with-pdo-pgsql=shared',
      '--with-pgsql=shared',
      '--with-pspell=shared',
      '--with-gettext=shared',
      '--with-gmp=shared',
      '--with-imap=shared',
      '--with-imap-ssl=shared',
      '--with-ldap=shared',
      '--with-ldap-sasl',
      '--with-zlib=shared',
      '--with-xsl=shared',
      '--with-snmp=shared',
      '--enable-mbstring=shared',
      '--enable-mbregex',
      '--enable-exif=shared',
      '--with-openssl=shared',
      '--enable-fpm',
      '--enable-pcntl=shared',
      '--with-readline'
    ]
  end

  def url
    "https://php.net/distributions/php-#{version}.tar.gz"
  end

  def archive_files
    ["#{port_path}/*"]
  end

  def archive_path_name
    'php'
  end

  def configure
    return if configured?

    md5_file = File.join(tmp_path, 'configure.md5')
    digest   = Digest::MD5.hexdigest(computed_options.to_s)
    File.open(md5_file, 'w') { |f| f.write digest }

    # LIBS=-lz enables using zlib when configuring
    execute('configure', ['bash', '-c', "LIBS=-lz ./configure #{computed_options.join ' '}"])
  end

  def major_version
    @major_version ||= version.match(/^(\d+\.\d+)/)[1]
  end

  def zts_path
    Dir["#{path}/lib/php/extensions/no-debug-non-zts-*"].first
  end

  def archive_filename
    "php7-#{version}-linux-x64-#{Time.now.utc.to_i}.tgz"
  end

  def setup_tar
    system <<-eof
      cp -a /usr/local/lib/x86_64-linux-gnu/librabbitmq.so* #{path}/lib/
      cp -a #{@hiredis_path}/lib/libhiredis.so* #{path}/lib/
      cp -a /usr/lib/libc-client.so* #{path}/lib/
      cp -a /usr/lib/libmcrypt.so* #{path}/lib
      cp -a /usr/lib/libaspell.so* #{path}/lib
      cp -a /usr/lib/libpspell.so* #{path}/lib
      cp -a /usr/lib/x86_64-linux-gnu/libmemcached.so* #{path}/lib
      cp -a /usr/lib/x86_64-linux-gnu/libcassandra.so* #{path}/lib
      cp -a /usr/lib/x86_64-linux-gnu/libuv.so* #{path}/lib
      cp -a /usr/lib/librdkafka.so* #{path}/lib
    eof

    if IonCubeRecipe.build_ioncube?(version)
      system "cp #{@ioncube_path}/ioncube/ioncube_loader_lin_#{major_version}.so #{zts_path}/ioncube.so"
    end

    system <<-eof
      # Remove unused files
      rm "#{path}/etc/php-fpm.conf.default"
      rm -rf "#{path}/include"
      rm -rf "#{path}/php"
      rm -rf "#{path}/lib/php/build"
      rm "#{path}/bin/php-cgi"
      find "#{path}/lib/php/extensions" -name "*.a" -type f -delete
    eof
  end
end

class Php7Meal
  attr_reader :name, :version

  def initialize(name, version, options)
    @name    = name
    @version = version
    @options = options
    @native_modules = []
    @extensions = []

    create_native_module_recipes
    create_extension_recipes

    (@native_modules + @extensions).each do |recipe|
      recipe.instance_variable_set('@php_path', php_recipe.path)
    end
  end

  def create_native_module_recipes
    return unless @options[:php_extensions_file]
    php_extensions_hash = YAML.load_file(@options[:php_extensions_file])

    php_extensions_hash['native_modules'].each do |hash|
      klass = Kernel.const_get(hash['klass'])

      @native_modules << klass.new(
        hash['name'],
        hash['version'],
        md5: hash['md5']
      )
    end
  end

  def create_extension_recipes
    return unless @options[:php_extensions_file]
    php_extensions_hash = YAML.load_file(@options[:php_extensions_file])

    php_extensions_hash['extensions'].each do |hash|
      klass = Kernel.const_get(hash['klass'])

      @extensions << klass.new(
        hash['name'],
        hash['version'],
        md5: hash['md5']
      )
    end

    @extensions.each do |recipe|
      case recipe.name
      when 'amqp'
        recipe.instance_variable_set('@rabbitmq_path', @native_modules.detect{|r| r.name=='rabbitmq'}.work_path)
      when 'lua'
        recipe.instance_variable_set('@lua_path', @native_modules.detect{|r| r.name=='lua'}.path)
      when 'phalcon'
        recipe.instance_variable_set('@php_version', 'php5')
      when 'phpiredis'
        recipe.instance_variable_set('@hiredis_path', @native_modules.detect{|r| r.name=='hiredis'}.path)
      end
    end
  end

  def cook
    system <<-eof
      sudo apt-get update
      sudo apt-get -y upgrade
      sudo apt-get -y install \
        libaspell-dev \
        libc-client2007e-dev \
        libcurl4-openssl-dev \
        libexpat1-dev \
        libgdbm-dev \
        libgmp-dev \
        libjpeg-dev \
        libldap2-dev \
        libmcrypt-dev \
        libmemcached-dev \
        libpng12-dev \
        libpspell-dev \
        libreadline-dev \
        libsasl2-dev \
        libsnmp-dev \
        libsqlite3-dev \
        libssl-dev \
        libxml2-dev \
        libzip-dev \
        libzookeeper-mt-dev \
        snmp-mibs-downloader
      sudo ln -fs /usr/include/x86_64-linux-gnu/gmp.h /usr/include/gmp.h
      sudo ln -fs /usr/lib/x86_64-linux-gnu/libldap.so /usr/lib/libldap.so
      sudo ln -fs /usr/lib/x86_64-linux-gnu/libldap_r.so /usr/lib/libldap_r.so
    eof

    install_cassandra_dependencies

    php_recipe.cook
    php_recipe.activate

    # native libraries
    @native_modules.each do |recipe|
      recipe.cook
    end

    # php extensions
    @extensions.each do |recipe|
      recipe.cook if should_cook?(recipe)
    end

    if OraclePeclRecipe.oracle_sdk?
      system 'ln -s /oracle/libclntsh.so.* /oracle/libclntsh.so'

      oracle_recipe.cook
      oracle_pdo_recipe.cook
    end
  end

  def should_cook?(recipe)
    case recipe.name
    when 'phalcon'
       PhalconRecipe.build_phalcon?(version)
    when 'ioncube'
       IonCubeRecipe.build_ioncube?(version)
    else
       true
    end
  end

  def url
    php_recipe.url
  end

  def archive_files
    php_recipe.archive_files
  end

  def archive_path_name
    php_recipe.archive_path_name
  end

  def archive_filename
    php_recipe.archive_filename
  end

  def setup_tar
    php_recipe.setup_tar
    if OraclePeclRecipe.oracle_sdk?
      oracle_recipe.setup_tar
      oracle_pdo_recipe.setup_tar
    end
  end

  private

  def files_hashs
    native_module_hashes = @native_modules.map do |recipe|
      recipe.send(:files_hashs)
    end.flatten

    extension_hashes = @extensions.map do |recipe|
      recipe.send(:files_hashs)
    end.flatten

    extension_hashes + native_module_hashes +
    (OraclePeclRecipe.oracle_sdk? ? oracle_recipe.send(:files_hashs) : []) +
    (OraclePeclRecipe.oracle_sdk? ? oracle_pdo_recipe.send(:files_hashs) : [])
  end

  def php_recipe
    hiredis_recipe = @native_modules.detect{|r| r.name=='hiredis'}
    ioncube_recipe = @extensions.detect{|r| r.name=='ioncube'}

    @php_recipe ||= Php7Recipe.new(@name, @version, {
      hiredis_path: hiredis_recipe.path,
      ioncube_path: ioncube_recipe.path
    }.merge(DetermineChecksum.new(@options).to_h))
  end

  def oracle_recipe
    @oracle_recipe ||= OraclePeclRecipe.new('oci8', '2.1.3', md5: '99fa44a82ecc5473820f1d810911f24f',
							     php_path: php_recipe.path)
  end

  def oracle_pdo_recipe
    @oracle_pdo_recipe ||= OraclePdoRecipe.new('pdo_oci', version,
                                               php_source: "#{php_recipe.send(:tmp_path)}/php-#{version}",
                                               php_path: php_recipe.path)
  end
end
