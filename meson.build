project('sdk', 'cpp', meson_version : '>= 0.37.1', default_options : ['cpp_std=c++14'])

# dependencies
compiler = meson.get_compiler('cpp')

ssldep = dependency('openssl', version : '>= 1.0.1')
boostdep = dependency('boost', modules : ['asio', 'system', 'thread'])

run_target('wally', command : 'tools/buildwally.sh')

# includes
autobahn_inc_dir = 'thirdparty/autobahn-cpp'
websocketpp_inc_dir = 'thirdparty/websocketpp-0.7.0'
msgpack_inc_dir = 'thirdparty/msgpack-2.1.1/include'
sdk_inc_dir = 'src'

incdir = include_directories([autobahn_inc_dir, msgpack_inc_dir, websocketpp_inc_dir, sdk_inc_dir])

# builds
subdirs = ['src']
foreach n : subdirs
    subdir(n)
endforeach

