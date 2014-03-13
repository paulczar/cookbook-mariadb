name 'galera-reference'
description 'Galera Reference Server Role'
run_list(
  'recipe[mariadb::server_galera]'
)
