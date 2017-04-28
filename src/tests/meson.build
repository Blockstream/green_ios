wss_connect = executable('wss_connect', 'wss_connect.cpp',
                         include_directories : incdir,
                         dependencies : [boostdep, ssldep, libga_dependency],
                         cpp_args : ['-DMSGPACK_DEFAULT_API_VERSION=1', '-Wno-deprecated-declarations'])

test('wss_connect', wss_connect)

