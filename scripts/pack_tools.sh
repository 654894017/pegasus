#!/bin/bash

function get_boost_lib()
{
    libname=`ldd ./DSN_ROOT/bin/pegasus_shell/pegasus_shell 2>/dev/null | grep boost_$2`
    libname=`echo $libname | cut -f1 -d" "`
    if [ $1 = "true" ]; then
        echo $BOOST_DIR/lib/$libname
    else
        echo `ldconfig -p|grep $libname|awk '{print $NF}'`
    fi
}

function get_stdcpp_lib()
{
    libname=`ldd ./DSN_ROOT/bin/pegasus_shell/pegasus_shell 2>/dev/null | grep libstdc++`
    libname=`echo $libname | cut -f1 -d" "`
    if [ $1 = "true" ]; then
        gcc_path=`which gcc`
        echo `dirname $gcc_path`/../lib64/$libname
    else
        echo `ldconfig -p|grep $libname|awk '{print $NF}'`
    fi
}

function get_lib()
{
    libname=`ldd ./DSN_ROOT/bin/pegasus_shell/pegasus_shell 2>/dev/null | grep $1`
    libname=`echo $libname | cut -f1 -d" "`
    echo `ldconfig -p | grep $libname | head -n 1 | awk '{print $NF}'`
}

function usage()
{
    echo "Options for subcommand 'pack_tools':"
    echo "  -h"
    echo "  -p|--update-package-template <minos-package-template-file-path>"
    echo "  -b|--custom-boost-lib"
    echo "  -g|--custom-gcc"
    exit 0
}

pwd="$( cd "$( dirname "$0"  )" && pwd )"
shell_dir="$( cd $pwd/.. && pwd )"
cd $shell_dir

if [ ! -f src/include/pegasus/git_commit.h ]
then
    echo "ERROR: src/include/pegasus/git_commit.h not found"
    exit -1
fi

if [ ! -f DSN_ROOT/bin/pegasus_shell/pegasus_shell ]
then
    echo "ERROR: DSN_ROOT/bin/pegasus_shell/pegasus_shell not found"
    exit -1
fi

if [ ! -f src/builder/CMAKE_OPTIONS ]
then
    echo "ERROR: src/builder/CMAKE_OPTIONS not found"
    exit -1
fi

if grep -q Debug src/builder/CMAKE_OPTIONS
then
    build_type=debug
else
    build_type=release
fi
version=`grep "VERSION" src/include/pegasus/version.h | cut -d "\"" -f 2`
commit_id=`grep "GIT_COMMIT" src/include/pegasus/git_commit.h | cut -d "\"" -f 2`
platform=`lsb_release -a 2>/dev/null | grep "Distributor ID" | awk '{print $3}' | tr '[A-Z]' '[a-z]'`
echo "Packaging pegasus tools $version ($commit_id) $platform $build_type ..."

pack_version=tools-$version-${commit_id:0:7}-${platform}-${build_type}
pack=pegasus-$pack_version

if [ -f ${pack}.tar.gz ]
then
    rm -f ${pack}.tar.gz
fi

if [ -d ${pack} ]
then
    rm -rf ${pack}
fi

pack_template=""
if [ -n "$MINOS_CONFIG_FILE" ]; then
    pack_template=`dirname $MINOS_CONFIG_FILE`/xiaomi-config/package/pegasus.yaml
fi

custom_boost_lib="false"
custom_gcc="false"

while [[ $# > 0 ]]; do
    option_key="$1"
    case $option_key in
        -p|--update-package-template)
            pack_template="$2"
            shift
            ;;
        -b|--custom-boost-lib)
            custom_boost_lib="true"
            ;;
        -g|--custom-gcc)
            custom_gcc="true"
            ;;
        -h|--help)
            usage
            ;;
    esac
    shift
done

mkdir -p ${pack}/DSN_ROOT
cp -v -r ./DSN_ROOT/* ${pack}/DSN_ROOT
cp -v ./run.sh ${pack}/

cp -v `get_boost_lib $custom_boost_lib system` ${pack}/DSN_ROOT/lib/
cp -v `get_boost_lib $custom_boost_lib filesystem` ${pack}/DSN_ROOT/lib/
cp -v `get_stdcpp_lib $custom_gcc` ${pack}/DSN_ROOT/lib/
cp -v `get_lib libreadline.so` ${pack}/DSN_ROOT/lib/
cp -v `get_lib libbz2.so` ${pack}/DSN_ROOT/lib/
cp -v `get_lib libz.so` ${pack}/DSN_ROOT/lib/
cp -v `get_lib libsnappy.so` ${pack}/DSN_ROOT/lib/
cp -v `get_lib libaio.so` ${pack}/DSN_ROOT/lib/

mkdir -p ${pack}/scripts
cp -v ./scripts/pegasus_kill_test.sh ${pack}/scripts/
cp -v ./scripts/*_zk.sh ${pack}/scripts/
cp -v ./scripts/scp-no-interactive ${pack}/scripts/
cp -v ./rdsn/scripts/linux/learn_stat.py ${pack}/scripts/

mkdir -p ${pack}/src/server
cp -v ./src/server/config-server.ini ${pack}/src/server/

mkdir -p ${pack}/src/shell
cp -v ./src/shell/config.ini ${pack}/src/shell/

mkdir -p ${pack}/src/test/kill_test
cp -v ./src/test/kill_test/config.ini ${pack}/src/test/kill_test/

cp -v ./src/config-bench.ini ${pack}/src/

echo "Pegasus Tools $version ($commit_id) $platform $build_type" >${pack}/VERSION

tar cfz ${pack}.tar.gz ${pack}

if [ -f $pack_template ]; then
    echo "Modifying $pack_template ..."
    sed -i "/^version:/c version: \"$pack_version\"" $pack_template
    sed -i "/^build:/c build: \"\.\/run.sh pack_tools\"" $pack_template
    sed -i "/^source:/c source: \"$PEGASUS_ROOT\"" $pack_template
fi

echo "Done"
