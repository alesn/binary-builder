# encoding: utf-8
require 'spec_helper'
require 'fileutils'
require 'open-uri'

describe 'building a binary', :integration do
  context 'when php7.1 is specified' do
    before(:all) do
      @extensions_dir = Dir.mktmpdir(nil, './spec')
      extensions_file = File.join(@extensions_dir, 'php7-extensions.yml')
      extensions_url  = 'https://raw.githubusercontent.com/cloudfoundry/public-buildpacks-ci-robots/master/binary-builds/php7-extensions.yml'

      File.write(extensions_file, open(extensions_url).read)
      run_binary_builder('php7', '7.1.0', "--md5=ec2218f97b4edbc35a2d7919ff37a662 --php-extensions-file=#{extensions_file}")
      @binary_tarball_location = Dir.glob(File.join(Dir.pwd, 'php7-7.1.0-linux-x64.tgz')).first
    end

    after(:all) do
      FileUtils.rm(@binary_tarball_location)
      FileUtils.rm_rf(@extensions_dir)
    end

    it 'builds the specified binary, tars it, and places it in your current working directory' do
      expect(File).to exist(@binary_tarball_location)

      php_version_cmd = %{./spec/assets/php-exerciser.sh 7.1.0 #{File.basename(@binary_tarball_location)} ./php/bin/php -r 'echo phpversion();'}

      output, status = run(php_version_cmd)

      expect(status).to be_success
      expect(output).to include('7.1.0')
    end

    it 'copies in *.so files for some of the compiled extensions' do
      expect(tar_contains_file('php/lib/librabbitmq.so.4')).to eq true
      expect(tar_contains_file('php/lib/libc-client.so.2007e')).to eq true
      expect(tar_contains_file('php/lib/libhiredis.so.0.13')).to eq true
      expect(tar_contains_file('php/lib/libmcrypt.so.4')).to eq true
      expect(tar_contains_file('php/lib/libpspell.so.15')).to eq true
      expect(tar_contains_file('php/lib/libmemcached.so.10')).to eq true
      expect(tar_contains_file('php/lib/libcassandra.so.2')).to eq true
      expect(tar_contains_file('php/lib/libuv.so.0.10')).to eq true
      expect(tar_contains_file('php/lib/librdkafka.so.1')).to eq true

      expect(tar_contains_file('php/lib/php/extensions/*/apcu.so')).to eq true
      # removing assertion until ioncube has PHP 7.1 support
      # Once this is done, this spec can probably be merged back with the 7.0.x specs
      #expect(tar_contains_file('php/lib/php/extensions/*/ioncube.so')).to eq true
      expect(tar_contains_file('php/lib/php/extensions/*/phpiredis.so')).to eq true
      # phalcon does not support php 7.1.x yet
      # https://github.com/phalcon/cphalcon/issues/12444
      expect(tar_contains_file('php/lib/php/extensions/*/phalcon.so')).to eq false

      expect(tar_contains_file('php/lib/libGeoIP.so.1')).to eq true
      expect(tar_contains_file('php/lib/php/extensions/*/geoip.so')).to eq true
      expect(tar_contains_file('php/geoipdb/lib/geoip_downloader.rb')).to eq true
      expect(tar_contains_file('php/geoipdb/bin/download_geoip_db.rb')).to eq true
    end
  end
end
