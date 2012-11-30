#!/bin/bash
set -e
cd `dirname $0`/..

git submodule update --init --recursive

PLATFORM=`uname -s`
PKGMGR=""

# locate's db may not exist
if locate -S >/dev/null 2>&1; then
  FIND="locate"
else
  FIND="find / -name"
fi

if [ "$PLATFORM" = "Darwin" ]; then
    if command -v brew; then
        echo "Found the homebrew package manager."
        PKGMGR="brew install"
    fi
fi

cd vendor

# check for the JCL
if [ ! -f classes/java/lang/Object.class ]; then
  DOWNLOAD_DIR=`mktemp -d jdk-download.XXX`
  cd $DOWNLOAD_DIR
    DEBS_DOMAIN="http://security.ubuntu.com/ubuntu/pool/main/o/openjdk-6"
    DEBS=("openjdk-6-jre-headless_6b24-1.11.5-0ubuntu1~11.10.1_i386.deb"
          "openjdk-6-jdk_6b24-1.11.5-0ubuntu1~11.10.1_i386.deb"
          "openjdk-6-jre-lib_6b24-1.11.5-0ubuntu1~11.10.1_all.deb")
    for DEB in ${DEBS[@]}; do
      wget $DEBS_DOMAIN/$DEB
      ar p $DEB data.tar.gz | tar zx
    done
  cd ..
  JARS=("rt.jar" "tools.jar" "resources.jar", "rhino.jar")
  for JAR in ${JARS[@]}; do
    JAR_PATH=`find $DOWNLOAD_DIR/usr -name $JAR`
    echo "Extracting the Java class library from $JAR_PATH"
    unzip -qq -o -d classes/ "$JAR_PATH"
  done
  test -e java_home || mv $DOWNLOAD_DIR/usr/lib/jvm/java-6-openjdk/jre java_home
  rm -rf $DOWNLOAD_DIR
fi

# check for jazzlib
if [ ! -f classes/java/util/zip/DeflaterEngine.class ]; then
  echo "patching the class library with Jazzlib"
  mkdir -p jazzlib && cd jazzlib
  if ! command -v wget >/dev/null && [ -n "$PKGMGR" ]; then
      $PKGMGR wget
  fi
  wget -q "http://downloads.sourceforge.net/project/jazzlib/jazzlib/0.07/jazzlib-binary-0.07-juz.zip"
  unzip -qq "jazzlib-binary-0.07-juz.zip"

  cp java/util/zip/*.class ../classes/java/util/zip/
  cd .. && rm -rf jazzlib
fi

cd ..  # back to start

# Make sure node is present and >= v0.8
if [[ `node -v` < "v0.8" ]]; then
  echo "node >= v0.8 required"
  if [ -n "$PKGMGR" ]; then
    $PKGMGR node
  else
    exit
  fi
fi 
echo "Installing required node modules"
make dependencies

echo "Using `javac -version 2>&1` to generate classfiles"
make java

if ! command -v bundle > /dev/null; then
    if command -v gem > /dev/null; then
        gem install bundler
    else
        echo "warning: could not install bundler because rubygems was not found!"
        echo "some dependencies may be missing."
    fi
fi

command -v bundle > /dev/null && bundle install

# does sed support extended regexps?
if ! sed -r "" </dev/null >/dev/null 2>&1 && ! command -v gsed >/dev/null; then
    if [ "$PLATFORM" = "Darwin" ] && [ -n "$PKGMGR" ]; then
        $PKGMGR gnu-sed
    else
        echo "warning: sed does not seem to support extended regular expressions."
        echo "Doppio can run without this, but it is needed for building the full website."
    fi
fi

# Intentionally fail if pygmentize doesn't exist.
echo "Checking for pygment (needed to generate docs)... `pygmentize -V`"

echo "Your environment should now be set up correctly."
echo "Run 'make test' (optionally with -j4) to test Doppio."
