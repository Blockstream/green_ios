project('sdk', 'cpp', meson_version : '>= 0.37.1', default_options : ['cpp_std=c++14'])

# dependencies
compiler = meson.get_compiler('cpp')

ssldep = dependency('openssl', version : '>= 1.0.1')
boostdep = dependency('boost', modules : ['asio', 'system', 'thread'])

clang_format = find_program('clang-format', required : false)

wally_path = join_paths(meson.current_source_dir(), 'src', 'wally', 'src', '.libs')
libwally_obj = compiler.find_library('wallycore', dirs : [wally_path], required : false)
if not libwally_obj.found()
    message('Building wallycore...')
    run_command('tools/buildwally.sh')
    libwally_obj = compiler.find_library('wallycore', dirs : [wally_path])
endif

run_target('wally', command : 'tools/buildwally.sh')

# includes
autobahn_inc_dir = 'thirdparty/autobahn-cpp'
websocketpp_inc_dir = 'thirdparty/websocketpp-0.7.0'
msgpack_inc_dir = 'thirdparty/msgpack-2.1.1/include'
sdk_inc_dir = 'src'
wally_inc_dir = 'src/wally/include'

incdir = include_directories([autobahn_inc_dir, msgpack_inc_dir, websocketpp_inc_dir, sdk_inc_dir, wally_inc_dir])

# builds
subdirs = ['src']
foreach n : subdirs
    subdir(n)
endforeach

