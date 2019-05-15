@echo off
rem Note: If you're getting an error like: "bash: ./bin/binary-builder: No such file or directory", this is due to buggy Docker 
rem not correctly mounting the contents of this directory as working directory for the docker container where the builder runs.
rem What helped was in Docker for Windows - Settings - Shared Drives to unshare and reshare this drive again

rem Path to my fork of nginx buildpack (develop branch)
set NGINX_BUILDPACK_DIR=../myCFNginxBuildpack

set /p NGINX_VERSION="Specify Nginx version to build: "

rem We need md5 hash of the official linux nginx binary distribution that will serve as the source
curl -sL http://nginx.org/download/nginx-%NGINX_VERSION%.tar.gz -o nginx-%NGINX_VERSION%.tar.gz
rem Get second line of CertUtil's output - md5 hash - into the variable NGINX_MD5
set "NGINX_MD5="
for /f "skip=1delims=" %%a in (
 'CertUtil -hashfile nginx-%NGINX_VERSION%.tar.gz MD5'
) do if not defined NGINX_MD5 set "NGINX_MD5=%%a"
del nginx-%NGINX_VERSION%.tar.gz

docker run -w /binary-builder -v /d/dev/myCFBinaryBuildpackBuilder:/binary-builder -it cloudfoundry/cflinuxfs3 bash ./bin/binary-builder --name=nginx-static --version=%NGINX_VERSION% --md5=%NGINX_MD5%

rem Move the built nginx binary to Nginx buildpack dir
move /Y nginx-static-%NGINX_VERSION%-linux-x64.tgz %NGINX_BUILDPACK_DIR%/dependencies/nginx-with-geoip-%NGINX_VERSION%-linux-x64.tgz 

echo *
echo *
echo Nginx binary has been built and copied into Nginx buildpack directory. Add a new entry in that repository's manifest.yml with the sha256 printed below:
echo ---

CertUtil -hashfile %NGINX_BUILDPACK_DIR%/dependencies/nginx-with-geoip-%NGINX_VERSION%-linux-x64.tgz SHA256
