name 'galera'
description 'Galera Server Role'
run_list(
  'recipe[mariadb::server_galera]'
)
