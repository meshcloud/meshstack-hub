# The shared PostgreSQL instances moved to the foundation, which imports them with their data.
removed {
  from = meshstack_building_block.postgres

  lifecycle {
    destroy = false
  }
}

removed {
  from = module.postgres_integration

  lifecycle {
    destroy = false
  }
}
