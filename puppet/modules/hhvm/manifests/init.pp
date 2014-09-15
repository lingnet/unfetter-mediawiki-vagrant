# == Class: hhvm
#
# This module provisions HHVM -- an open-source, high-performance
# virtual machine for PHP.
#
# The layout of configuration files in /etc/hhvm is as follows:
#
#   /etc/hhvm
#   │
#   ├── config.hdf        ┐
#   │                     ├ Settings for CLI mode
#   ├── php.ini           ┘
#   │
#   └── fcgi
#       │
#       ├── config.hdf    ┐
#       │                 ├ Settings for FastCGI mode
#       └── php.ini       ┘
#
# The CLI configs are located in the paths HHVM automatically loads by
# default. This makes it easy to invoke HHVM from the command line,
# because no special arguments are required.
#
# HHVM is in the process of standardizing on the INI file format for
# configuration files. At the moment (Aug 2014) there are still some
# options that can only be set using the deprecated HDF syntax. This
# is why we have two configuration files for each SAPI.
#
# The exact purpose of certain options is a little mysterious. The
# documentation is getting better, but expect to have to dig around in
# the source code.
#
# == Parameters:
#
# [*common_settings*]
#   A hash of default php.ini settings that apply to both CLI and FastCGI
#   mode.
#
# [*fcgi_settings*]
#   A hash of php.ini settings for that only apply to FastCGI mode.
#
# [*logroot*]
#   Parent directory to write log files to. An 'hhvm' subdirectory will be
#   made here to store access and error logs and core dumps . (eg /var/log or
#   /vagrant/logs)
#
class hhvm (
  $common_settings,
  $fcgi_settings,
  $logroot,
) {
    include ::apache
    include ::apache::mod::proxy_fcgi

    package { [ 'hhvm', 'hhvm-dev', 'hhvm-fss', 'hhvm-luasandbox', 'hhvm-wikidiff2' ]:
        ensure => latest,
        before => Service['hhvm'],
    }

    env::alternative { 'hhvm_as_default_php':
        alternative => 'php',
        target      => '/usr/bin/hhvm',
        priority    => 20,
        require     => Package['hhvm'],
    }

    file { ['/etc/hhvm', '/etc/hhvm/fcgi']:
        ensure => directory,
    }

    file { '/etc/hhvm/php.ini':
        content => php_ini($common_settings),
    }

    file { '/etc/hhvm/fcgi/php.ini':
        content => php_ini($common_settings, $fcgi_settings),
        notify  => Service['hhvm'],
    }

    file { '/etc/hhvm/config.hdf':
        content => template('hhvm/config.hdf.erb'),
        require => Package['hhvm'],
        notify  => Service['hhvm'],
    }

    file { '/etc/init/hhvm.conf':
        ensure  => file,
        content => template('hhvm/hhvm.conf.erb'),
        require => [ Env::Alternative['hhvm_as_default_php'], File['/etc/hhvm/config.hdf'] ],
        notify  => Service['hhvm'],
    }

    service { 'hhvm':
        ensure   => running,
        provider => upstart,
        require  => File['/etc/init/hhvm.conf'],
    }

    file { '/usr/local/bin/hhvmsh':
        source => 'puppet:///modules/hhvm/hhvmsh',
        mode   => '0555',
    }

    apache::site { 'hhvm_admin':
        ensure  => present,
        content => template('hhvm/admin-apache-site.erb'),
        require => Class['::apache::mod::proxy_fcgi'],
    }
}
