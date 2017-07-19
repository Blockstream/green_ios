swift_sources = ['Sources/GA.swift']

ga_swift_module = custom_target('GA.swiftmodule',
                      command : ['swift', 'build', '--chdir', join_paths(meson.source_root(), 'src', 'swift', 'GA'),
                                 '-Xswiftc', '-I../..', '-Xswiftc', '-emit-library', '-Xswiftc', '-L' + join_paths(meson.build_root(), 'src')],
                      input : swift_sources,
                      output : 'GA.swiftmodule',
                      depends : libga,
                      build_always : true)

ga_swift_module_dep = declare_dependency(dependencies : libga_dep)
