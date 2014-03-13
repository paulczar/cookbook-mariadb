name              'mariadb'
maintainer        'Joe Rocklin'
maintainer_email  'joe.rocklin@gmail.com'
license           'Apache 2.0'
description       'Installs and configures mariadb for client or server'
long_description  IO.read(File.join(File.dirname(__FILE__), 'README.md'))
version           '2.0.2'

# actually tested on
supports 'ubuntu'

# # code bits around, untested. remove?
supports 'redhat'
supports 'debian'

depends 'yum'
depends 'yum-epel'
depends 'apt'
depends 'openssl'
depends 'build-essential'
