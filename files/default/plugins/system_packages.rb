Ohai.plugin(:SystemPackages) do

  provides 'system_packages'
  %w{holding upgradeable installed insecure}.each do |list|
    provides "system_packages/#{list}"
  end

  depends 'platform', 'lsb'

  def create_objects
    system_packages Mash.new
    system_packages[:holding] = Array.new
    system_packages[:insecure] = Array.new
    system_packages[:upgradeable] = Mash.new
    system_packages[:installed] = Mash.new
  end

  # We only support Debian/-derivs currently
  collect_data(:linux) do
    case platform_family
    when 'debian'
      create_objects
      # Get packages which are on hold or are upgradeable
      so = shell_out('apt-get -q -s -f dist-upgrade')

      stage = :initial
      so.stdout.lines do |line|
        # Reading stages in this order
        #   :initial
        #   :holding
        #   :upgradeable
        case stage
        when :initial
          case line
          when /^The following packages have been kept back/
            stage = :holding
          when /^The following packages will be upgraded:/
            stage = :upgradeable
          end

        when :holding
          unless line =~ /^\s/
            stage = :upgradeable
            next
          end
          system_packages[:holding] += line.split

        when :upgradeable
          next unless line =~ /^Inst (\S+) \[.+\] \((\S+) /
          system_packages[:upgradeable][$1] = $2
        end
      end

      # Get packages which are upgradeable and come from security
      so = shell_out("apt-cache -qq showpkg #{system_packages[:upgradeable].keys.join(' ')}")

      package, version = nil, nil
      so.stdout.lines do |line|
        line.chomp!
        if line =~ /^Package: (\S+)$/
          package = $1
          version = system_packages[:upgradeable][package]
        elsif version and line =~ /^#{version}\s+\(/
          paths = line.split(/\s+/).drop(1)
          if paths.any? {|p| p =~ /_#{lsb[:codename]}-security_/}
            system_packages[:insecure] << package
          end
        end
      end

      # Get current versions of all installed packages
      so = shell_out("dpkg-query --show --showformat='${Package} ${Version} ${Status}\\n'")
      so.stdout.lines do |line|
        next unless line =~ /^(\S+) (\S+) (\S+) (\S+) (\S+)\s*$/

        package_name = $1
        version = $2
        status = $5

        system_packages[:installed][$1] = {:version => version, :status => status}
      end
    end

  end
end
