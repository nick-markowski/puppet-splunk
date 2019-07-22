# @summary
#   This class takes a small number of arguments (can be set through Hiera) and
#   generates sane default values installation media names and locations.
#   Default ports can also be specified here. This is a parameters class, and
#   contributes no resources to the graph. Rather, it only sets values for
#   parameters to be consumed by child classes.
#
# @param package_ensure
#   Passed to the splunk package resource to determine how splunk will be
#   installed.  If splunk is not installed, you *must* specify a version
#   and release, eg. 7.2.4.2-fb30470262e3, for this params class to properly
#   function.
#
# @param splunkd_port
#   The splunkd port.
#
# @param logging_port
#   The port on which to send logs, and listen for logs.
#
# @param server
#   Optional fqdn or IP of the Splunk Enterprise server.  Used for setting up
#   the default TCP output and input.
#
# @param splunk_user
#   The user that splunk runs as.
#
# @param src_root
#   The root URL at which to find the splunk packages. The sane-default logic
#   assumes that the packages are located under this URL in the same way that
#   they are placed on download.splunk.com. The URL can be any protocol that
#   the puppet/archive module supports. This includes both puppet:// and
#   http://.
#
#   The expected directory structure is:
#
#   ```
#   $root_url/
#   └── products/
#       ├── universalforwarder/
#       │   └── releases/
#       |       └── $version/
#       |           └── $platform/
#       |               └── splunkforwarder-${version}-${release}-${additl}
#       └── splunk/
#           └── releases/
#               └── $version/
#                   └── $platform/
#                       └── splunk-${version}-${release}-${additl}
#   ```
#
#   A semi-populated example of `src_root` contains:
#
#   ```
#   $root_url/
#   └── products/
#       ├── universalforwarder/
#       │   └── releases/
#       |       └── 7.2.4.2/
#       |           ├── linux/
#       |           |   ├── splunkforwarder-7.2.4.2-fb30470262e3-linux-2.6-amd64.deb
#       |           |   ├── splunkforwarder-7.2.4.2-fb30470262e3-linux-2.6-intel.deb
#       |           |   └── splunkforwarder-7.2.4.2-fb30470262e3-linux-2.6-x86_64.rpm
#       |           ├── solaris/
#       |           └── windows/
#       |               └── splunkforwarder-7.2.4.2-fb30470262e3-x64-release.msi
#       └── splunk/
#           └── releases/
#               └── 7.2.4.2/
#                   └── linux/
#                       ├── splunk-7.2.4.2-fb30470262e3-linux-2.6-amd64.deb
#                       ├── splunk-7.2.4.2-fb30470262e3-linux-2.6-intel.deb
#                       └── splunk-7.2.4.2-fb30470262e3-linux-2.6-x86_64.rpm
#   ```
#
# @param boot_start
#   Enable Splunk to start at boot, create a system service file.
#
#   WARNING: Toggling `boot_start` from `false` to `true` will cause a restart of
#   Splunk Enterprise and Forwarder services.
#
# @param installdir
#   Optional directory in which to install and manage Splunk Enterprise
#
class splunk::enterprise::params (
  Splunk::Pkgensure $package_ensure = 'installed',
  String[1] $src_root               = 'https://download.splunk.com',
  Stdlib::Port $splunkd_port        = 8089,
  Stdlib::Port $logging_port        = 9997,
  String[1] $server                 = 'splunk',
  Optional[String[1]] $installdir   = undef,
  Boolean $boot_start               = true,
  String[1] $splunk_user            = $facts['os']['family'] ? {
    'windows' => 'Administrator',
    default => 'root'
  },
) {

  # Splunk version is specified
  if $package_ensure =~ /^\d/ {
    $version = split($package_ensure,'-')[0]
    $release = split($package_ensure,'-')[1]
  }
  # Splunk version is not specified, and Splunk is not installed
  elsif ($package_ensure !~ /^\d/) and (!has_key($facts['splunkenterprise'],'version')) {
    fail('No splunk version detected, you need to specify `$splunk::enterprise::params::package_ensure` in the form `version-release`, eg. 7.2.4.2-fb30470262e3')
  }
  # Splunk version is not specified, and Splunk is installed
  else {
    $version = $facts['splunkenterprise']['version']
    $release = $facts['splunkenterprise']['release']
  }

  # To generate password_content, change the password on enterprise or
  # forwarder, then distribute the contents of the splunk.secret and passwd
  # files accross all nodes.
  # By default the parameters provided are for admin/changeme password.
  $manage_password       = false
  $seed_password         = false
  $reset_seeded_password = false
  $secret                = 'hhy9DOGqli4.aZWCuGvz8stcqT2/OSJUZuyWHKc4wnJtQ6IZu2bfjeElgYmGHN9RWIT3zs5hRJcX1wGerpMNObWhFue78jZMALs3c3Mzc6CzM98/yGYdfcvWMo1HRdKn82LVeBJI5dNznlZWfzg6xdywWbeUVQZcOZtODi10hdxSJ4I3wmCv0nmkSWMVOEKHxti6QLgjfuj/MOoh8.2pM0/CqF5u6ORAzqFZ8Qf3c27uVEahy7ShxSv2K4K41z'
  $password_hash         = '$6$pIE/xAyP9mvBaewv$4GYFxC0SqonT6/x8qGcZXVCRLUVKODj9drDjdu/JJQ/Iw0Gg.aTkFzCjNAbaK4zcCHbphFz1g1HK18Z2bI92M0'
  $password_content      = ":admin:${password_hash}::Administrator:admin:changeme@example.com::"

  if $facts['os']['family'] == 'windows' {
    $staging_dir        = "${facts['archive_windir']}\\splunk"
    $homedir = pick($installdir, 'C:\\Program Files\\Splunk')
  } else {
    $staging_dir        = '/opt/staging/splunk'
    $homedir = pick($installdir, '/opt/splunk')
  }

  # Settings common to a kernel
  case $facts['kernel'] {
    'Linux': {
      $path_delimiter                  = '/'
      $seed_config_file     = "${homedir}/etc/system/local/user-seed.conf"
      $password_config_file = "${homedir}/etc/passwd"
      $secret_file          = "${homedir}/etc/splunk.secret"
      $src_subdir           = 'linux'
      $confdir              = "${homedir}/etc"
      $install_options      = []
      # Systemd not supported until Splunk 7.2.2
      if $facts['service_provider'] == 'systemd' and versioncmp($version, '7.2.2') >= 0 {
        $service      = 'Splunkd'
        $service_file = '/etc/systemd/system/multi-user.target.wants/Splunkd.service'
      }
      else {
        $service      = 'splunk'
        $service_file = '/etc/init.d/splunk'
      }
    }
    'SunOS': {
      $path_delimiter                  = '/'
      $seed_config_file     = "${homedir}/etc/system/local/user-seed.conf"
      $password_config_file = "${homedir}/etc/passwd"
      $secret_file          = "${homedir}/etc/splunk.secret"
      $src_subdir           = 'solaris'
      $confdir              = "${homedir}/etc"
      $install_options      = []
      # Systemd not supported until Splunk 7.2.2
      if $facts['service_provider'] == 'systemd' and versioncmp($version, '7.2.2') >= 0 {
        $service      = 'Splunkd'
        $service_file = '/etc/systemd/system/multi-user.target.wants/Splunkd.service'
      }
      else {
        $service      = 'splunk'
        $service_file = '/etc/init.d/splunk'
      }
    }
    'windows': {
      $path_delimiter                  = '\\'
      $seed_config_file     = "${homedir}\\etc\\system\\local\\user-seed.conf"
      $password_config_file = "${homedir}\\etc\\passwd"
      $src_subdir           = 'windows'
      $service              = 'splunkd' # Not validated
      $service_file          = "${homedir}\\dummy" # Not used in Windows, but attribute must be defined with a valid path
      $confdir              = "${homedir}\\etc"
      $install_options     = [
        { 'INSTALLDIR' => $homedir },
        { 'SPLUNKD_PORT' => String($splunkd_port) },
        'AGREETOLICENSE=Yes',
        'LAUNCHSPLUNK=0',
      ]
    }
    default: { fail("splunk module does not support kernel ${facts['kernel']}") }
  }

  # Settings common to an OS family
  case $facts['os']['family'] {
    'RedHat':  { $package_provider = 'rpm'  }
    'Debian':  { $package_provider = 'dpkg' }
    'Solaris': { $package_provider = 'sun'  }
    'windows': { $package_provider = 'windows' }
    default:   { $package_provider = undef  } # Don't define a $package_provider
  }

  # Settings specific to an architecture as well as an OS family
  case "${facts['os']['family']} ${facts['architecture']}" {
    'RedHat i386': {
      $package_suffix          = "${version}-${release}.i386.rpm"
      $package_name = 'splunk'
    }
    'RedHat x86_64': {
      $package_suffix          = "${version}-${release}-linux-2.6-x86_64.rpm"
      $package_name = 'splunk'
    }
    'Debian i386': {
      $package_suffix          = "${version}-${release}-linux-2.6-intel.deb"
      $package_name = 'splunk'
    }
    'Debian amd64': {
      $package_suffix          = "${version}-${release}-linux-2.6-amd64.deb"
      $package_name = 'splunk'
    }
    /^(W|w)indows (x86|i386)$/: {
      $package_suffix          = "${version}-${release}-x86-release.msi"
      $package_name = 'Splunk Enterprise'
    }
    /^(W|w)indows (x64|x86_64)$/: {
      $package_suffix          = "${version}-${release}-x64-release.msi"
      $package_name = 'Splunk Enterprise'
    }
    'Solaris i86pc': {
      $package_suffix          = "${version}-${release}-solaris-10-intel.pkg"
      $package_name = 'splunk'
    }
    'Solaris sun4v': {
      $package_suffix          = "${version}-${release}-solaris-8-sparc.pkg"
      $package_name = 'splunk'
    }
    default: { fail("unsupported osfamily/arch ${facts['os']['family']}/${facts['architecture']}") }
  }

  $src_package = "splunk-${package_suffix}"
  $package_src    = "${src_root}/products/splunk/releases/${version}/${src_subdir}/${src_package}"

  # A meta resource so providers know where splunk is installed:
  splunk_config { 'splunk':
    server_installdir    => $homedir,
    server_confdir       => $confdir,
  }
}
