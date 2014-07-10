require 'pathname'

module MediaWikiVagrant
    # Represents the current environment from which MediaWiki-Vagrant commands
    # are executed.
    #
    class Environment
        STALENESS = 604800

        # Initialize a new environment for the given directory.
        #
        def initialize(directory)
            @directory = directory
            @path = Pathname.new(@directory)
        end

        # The HEAD commit of local master branch, if we're executing from
        # within a cloned Git repo.
        #
        def commit
            master = path('.git/refs/heads/master')
            master.read[0..8] if master.exist?
        end

        # Returns an absolute path from the given relative path.
        #
        # @return [Pathname]
        #
        def path(*subpaths)
            @path.join(*subpaths)
        end

        # Removes all enabled roles that are no longer available.
        #
        def prune_roles
            update_roles(roles_enabled & roles_available)
        end

        # Returns all available Puppet roles.
        #
        # @return [Array]
        #
        def roles_available
            manifests = Dir[manifest_path('roles/*.pp')]
            manifests.map! { |file| File.read(file).match(/^class\s*role::(\w+)/) { |m| m[1] } }
            manifests.compact.sort.uniq - ['generic', 'mediawiki']
        end

        # Returns enabled Puppet roles.
        #
        # @return [Array]
        #
        def roles_enabled
            return [] unless role_manifest.exist?

            roles = role_manifest.each_line.map { |l| l.match(/^[^#]*include role::(\S+)/) { |m| m[1] } }
            roles.compact.sort.uniq
        end

        # Updates the enabled Puppet roles to the given set.
        #
        def update_roles(roles)
            role_manifest.open('w') do |f|
                f.puts '# This file is managed by Vagrant. Do not edit.'
                f.puts '# Use "vagrant list-roles / enable-role / disable-role" instead.'
                f.puts roles.sort.uniq.map { |r| "include role::#{r.sub(/^role::/, '')}" }.join("\n")
            end
        end

        # If it has been a week or more since remote commits have been fetched,
        # run 'git fetch origin', unless the user disabled automatic fetching.
        # You can disable automatic fetching by creating an empty 'no-updates'
        # file in the root directory of your repository.
        #
        def update
            if stale_head? && !(ENV.include?('MWV_NO_UPDATE') || path('no-update').exist?)
                system('git fetch origin', chdir: @directory)
            end
        end

        private

        def manifest_path(*subpaths)
            path('puppet/manifests', *subpaths)
        end

        def role_manifest
            manifest_path('manifests.d/vagrant-managed.pp')
        end

        def stale_head?
            head = path('.git/FETCH_HEAD')
            head.exist? && (Time.now - head.mtime) > STALENESS
        end
    end
end