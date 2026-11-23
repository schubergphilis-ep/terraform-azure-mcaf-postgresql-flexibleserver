locals {
  # Databases that declare local PostgreSQL users. These log on with a password, so they need
  # password authentication on the server.
  databases_with_local_users = [
    for name, db in var.databases : name
    if length(db.local_readers) + length(db.local_writers) + length(db.local_admins) > 0
  ]
}
