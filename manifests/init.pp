# == Class: xtrabackup
#
# Configures xtrabackup to take MySQL database backups
#
# === Parameters
#
# [*dbuser*]
#   Database username (Required)
# [*dbpass*]
#   Database password (Required)
# [*hour*]
#   Hour to run at.  Cron format, */3 or 3,6,9,12,18,21 are valid examples.
#   (Required)
# [*minute*]
#   Minute to run at.  Cron format.
#   (Required)
# [*workdir*]
#   Working directory.  The volume it is on needs at least as much free space as
#   total database size on disk.  Must already exist.
#   (Optional, uses /tmp by default)
# [*outputdir*]
#   Directory to write backups to.  If sshdest is also specified, will be the remote 
#   database host.  Must already exist.
#   (Required)
# [*sshdest*]
#   Destination host to send to via SSH.  Assumes keys already set up.
#   Prefix with username if not root.
#   (Optional, writes to local machine if not set)
# [*sshkey*]
#   SSH private key to use, if not default /root/.ssh/id_rsa or similar
#   (Optional if sshdest is specified)
# [*keeydays*]
#   Delete backups older than this age in days.  THIS WILL CLEAR ALL FILES IN
#   outputdir!!
#   (Optional, disabled by default)
# [*gzip*]
#   Whether to compress backups using gzip
#   (Optional, enabled by default)
# [*parallel*]
#   Speed up backup by using this many theads.
#   (Optional, defaults to 1)
# [*slaveinfo*]
#   Record master info so that a slave can be created from this backup.
#   (Optional, disabled by default)
# [*safeslave*]
#   Stop slaving and connections to it whilst taking the backup, re-starting when
#   finished.  Off by default, strongly recommended for slaves.
#   (Optional, disabled by default)
# [*addrepo*]
#   Whether to add the Percona repositories.  Only supported for RedHat presently.
#   Enabled by default, pass 'false' to disable.
#   (Optional, enabled by default)
#
# === Examples
#
#  A simple example which takes backups at 3am every morning, creates compressed
#  backups on a locally mounted volume and stores them for two weeks:
#
#  class { "xtrabackup":
#    dbuser    => "root",
#    dbpass    => "rootdbpass",
#    hour      => 3,
#    minute    => 0,
#    keepdays  => 14,
#    workdir   => "/root/backupworkdir",
#    outputdir => "/mnt/nfs/mysqlbackups",
#  }
#
# === Authors
#
# Sam Bashton <sam@bashton.com>
#
# === Copyright
#
# Copyright 2013 Bashton Ltd
#
class xtrabackup ($dbuser,             # Database username
                  $dbpass,             # Database password
                  $hour,               # Cron hour
                  $minute,             # Cron minute
                  $workdir   = "/tmp", # Working directory
                  $outputdir,          # Directory to output to
                  $sshdest   = undef,  # SSH destination
                  $sshkey    = undef,  # SSH private key to use
                  $keepdays  = undef,  # Keep the last x days of backups
                  $gzip      = true,   # Compress using gzip
                  $parallel  = 1,      # Threads to use
                  $slaveinfo = undef,  # Record master log pos if true
                  $safeslave = undef,  # Disconnect clients from slave
                  $addrepo   = true    # Add the Percona yum/apt repo
                 ) {

  if ($addrepo) {
      if ($osfamily == "RedHat") {
        yumrepo { "percona":
          name     => "Percona-Repository",
          gpgkey   => "http://www.percona.com/downloads/RPM-GPG-KEY-percona",
          gpgcheck => "1",
          baseurl  => 'http://repo.percona.com/centos/$releasever/os/$basearch/',
          enabled  => "1",
        }
      } else {
        fail("Repository addition not supported for your distro")
      }
  }

  package { "percona-xtrabackup":
    ensure => installed,
  }

  file { "/usr/local/bin/mysql-backup":
    owner   => "root",
    group   => "root",
    mode    => 700,
    content => template('xtrabackup/backupscript.sh.erb')
  }

  file { "/usr/local/bin/mysql-backup-restore":
    owner   => "root",
    group   => "root",
    mode    => 700,
    content => template('xtrabackup/restorescript.sh.erb')
  }

  cron { "xtrabackup":
    command => "/usr/local/bin/mysql-backup",
    hour    => $hour,
    minute  => $minute,
  }

}
