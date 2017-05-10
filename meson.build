project('sdk', ['c', 'cpp'], meson_version : '>= 0.37.1', default_options : ['cpp_std=c++14'])

# dependencies
compiler = meson.get_compiler('cpp')

check_headers = [
    'sys/syscall.h',
    'malloc.h',
    'unistd.h',
# c++ specific. stdlib should be installed anyhow
    'algorithm',
    'array',
    'memory',
    'thread',
    'type_traits',
    'unordered_map',
    'vector'
]

foreach h : check_headers
  compiler.has_header(h)
endforeach

ssldep = dependency('openssl', version : '>= 1.0.1')

clang_format = find_program('clang-format', required : false)

threads_dep = dependency('threads')


boost_lib_dir = join_paths(meson.current_source_dir(), 'thirdparty', 'boost_1_64_0', 'build', 'lib')
boost_dep = dependency('boost', modules : ['system', 'thread'], required : false)
if not boost_dep.found()
    message('Building boost...')
    run_command('tools/buildboost.sh')
    boost_dep = dependency('boost', modules : ['system', 'thread'])
endif

wally_lib_dir = join_paths(meson.current_source_dir(), 'src', 'wally', 'src', '.libs')
wally_lib = compiler.find_library('wallycore', dirs : [wally_lib_dir], required : false)
if not wally_lib.found()
    message('Building wallycore...')
    run_command('tools/buildwally.sh')
    compiler.find_library('wallycore', dirs : [wally_lib_dir])
endif

openssl_lib_dir = join_paths(meson.current_source_dir(), 'thirdparty', 'openssl-1.0.2k', 'build', 'lib')
openssl_dep = dependency('openssl', version : '>= 9.9.9', required : false)
if not openssl_dep.found()
    message('Building openssl...')
    run_command('tools/buildopenssl.sh')
    openssl_dep = dependency('openssl', version : '>= 1.0.2')
endif

run_target('boost', command : 'tools/buildboost.sh')
run_target('openssl', command : 'tools/buildopenssl.sh')
run_target('wally', command : 'tools/buildwally.sh')

# includes
autobahn_inc_dir = join_paths('thirdparty', 'autobahn-cpp')
boost_inc_dir = join_paths('thirdparty', 'boost_1_64_0', 'build', 'include')
msgpack_inc_dir = join_paths('thirdparty', 'msgpack-2.1.1', 'include')
sdk_inc_dir = 'src'
wally_inc_dir = join_paths('src', 'wally', 'include')
websocketpp_inc_dir = join_paths('thirdparty', 'websocketpp-0.7.0')

incdir = include_directories([autobahn_inc_dir, boost_inc_dir, msgpack_inc_dir, websocketpp_inc_dir, sdk_inc_dir, wally_inc_dir])

# builds
subdirs = ['src']
foreach n : subdirs
    subdir(n)
endforeach

