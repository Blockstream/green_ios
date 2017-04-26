project('sdk', 'cpp', meson_version : '>= 0.39.1', default_options : ['cpp_std=c++14'])

# dependencies
compiler = meson.get_compiler('cpp')

ssldep = dependency('openssl', version : '>= 1.0.2')
boostdep = dependency('boost', modules : ['asio', 'system', 'thread'])

# includes
autobahn_inc_dir = 'thirdparty/autobahn-cpp'
websocketpp_inc_dir = 'thirdparty/websocketpp-0.7.0'
msgpack_inc_dir = 'thirdparty/msgpack-2.1.1/include'

incdir = include_directories([autobahn_inc_dir, msgpack_inc_dir, websocketpp_inc_dir])

# builds
subdirs = ['src']
foreach n : subdirs
    subdir(n)
endforeach

