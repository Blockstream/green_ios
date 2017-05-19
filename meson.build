project('sdk', ['c', 'cpp'], meson_version : '>= 0.37.1', default_options : ['cpp_std=c++14'])

# dependencies
compiler = meson.get_compiler('cpp')

check_headers = [
    'fcntl.h',
    'sys/stat.h',
    'unistd.h'
]

foreach h : check_headers
  compiler.has_header(h)
endforeach

clang_format = find_program('clang-format', required : false)

threads_dep = dependency('threads')


boost_lib_dir = join_paths(meson.current_build_dir(), 'thirdparty', 'boost_1_64_0', 'build', 'lib')
boost_dep = dependency('boost', modules : ['system', 'thread'], required : false)
if not boost_dep.found()
    message('Building boost...')
    if not meson.is_cross_build()
        run_command('tools/buildboost.sh')
    else
        res = run_command('tools/buildboost.sh', '--arm')
        output = res.stdout().strip()
        errortxt = res.stderr().strip()
        message(output)
        message(errortxt)
    endif
    boost_dep = dependency('boost', modules : ['system', 'thread'])
endif

wally_lib_dir = join_paths(meson.current_build_dir(), 'thirdparty', 'libwally-core', 'build', 'lib')
wally_dep = dependency('wallycore', version : '>= 9.9.9', required : false)
if not wally_dep.found()
    message('Building wallycore...')
    if not meson.is_cross_build()
        run_command('tools/buildwally.sh')
    else
        res = run_command('tools/buildwally.sh', '--arm')
        output = res.stdout().strip()
        errortxt = res.stderr().strip()
        message(output)
        message(errortxt)
    endif
    wally_dep = dependency('wallycore')
endif

openssl_lib_dir = join_paths(meson.current_build_dir(), 'thirdparty', 'openssl-1.0.2k', 'build', 'lib')
openssl_dep = dependency('openssl', version : '>= 9.9.9', required : false)
if not openssl_dep.found()
    message('Building openssl...')
    if not meson.is_cross_build()
        run_command('tools/buildopenssl.sh')
    else
        res = run_command('tools/buildopenssl.sh', '--arm')
        output = res.stdout().strip()
        errortxt = res.stderr().strip()
        message(output)
        message(errortxt)
    endif
    openssl_dep = dependency('openssl', version : '>= 1.0.2')
endif

run_target('boost', command : 'tools/buildboost.sh')
run_target('openssl', command : 'tools/buildopenssl.sh')
run_target('wally', command : 'tools/buildwally.sh')

# includes
autobahn_inc_dir = join_paths('thirdparty', 'autobahn-cpp')
boost_inc_dir = join_paths(meson.current_build_dir().split('/')[-1], 'thirdparty', 'boost_1_64_0', 'build', 'include')
openssl_inc_dir = join_paths(meson.current_build_dir().split('/')[-1], 'thirdparty', 'openssl-1.0.2k', 'build', 'include')
msgpack_inc_dir = join_paths('thirdparty', 'msgpack-2.1.1', 'include')
sdk_inc_dir = 'src'
wally_inc_dir = join_paths('src', 'wally', 'include')
websocketpp_inc_dir = join_paths('thirdparty', 'websocketpp-0.7.0')

incdir = include_directories([autobahn_inc_dir, boost_inc_dir, msgpack_inc_dir, openssl_inc_dir, sdk_inc_dir, wally_inc_dir, websocketpp_inc_dir])

# builds
subdirs = ['src']
foreach n : subdirs
    subdir(n)
endforeach

