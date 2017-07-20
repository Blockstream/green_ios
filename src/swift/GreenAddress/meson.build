swift_sources = ['Sources/GreenAddress.swift']

swift_cmd_line = []
if build_machine.system() == 'darwin'
    swift_cmd_line = ['xcrun', '--sdk', 'macosx']
endif

swift_cmd_line += ['swift', 'build', '--chdir', join_paths(meson.source_root(), 'src', 'swift', 'GreenAddress'),
                   '-Xswiftc', '-I../..',
                   '-Xswiftc', '-I' + join_paths(meson.build_root(), 'libwally-core', 'build', 'include'),
                   '-Xswiftc', '-emit-library',
                   '-Xswiftc', '-L' + join_paths(meson.build_root(), 'src')]

ga_swift_module = custom_target('GA.swiftmodule',
                      command : swift_cmd_line,
                      input : swift_sources,
                      output : 'GA.swiftmodule',
                      depends : libga,
                      build_always : true)

ga_swift_module_dep = declare_dependency(dependencies : libga_dep)
