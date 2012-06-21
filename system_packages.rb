provides 'system_packages'
system_packages Mash.new

require_plugin 'platform'
require_plugin "#{platform_family}::system_packages"
