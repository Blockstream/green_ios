c_cpp_sources = [
    'green-cli.c'
]

if clang_format.found()
    custom_target('examples-clang-format', input : c_cpp_sources, output : 'clang-format', command : [clang_format, '-i', '@INPUT@'])
endif

dependencies = [libga_dep]

if host_machine.cpu_family().contains('iphone')
    dependencies += [archiver_dep]
endif

c_cpp_args = []
link_args = []
#if compiler.get_id() == 'gcc'
#    c_cpp_args = ['-fpie']
#    link_args = ['-Wl,-pie']
#endif

foreach source : c_cpp_sources
    exe_name = source.split('.')[0]
    exe_sources = [source]
    exe = executable(exe_name,
                     exe_sources,
                     c_args : c_cpp_args,
                     cpp_args : c_cpp_args,
                     link_args : link_args,
                     include_directories : incdir,
                     dependencies : dependencies)
endforeach
