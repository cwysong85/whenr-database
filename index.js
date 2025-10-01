/**
 * @whenr/whenr-database
 *
 * Shared database package for Whenr application.
 * Provides Prisma schema and utilities for all services.
 */

const path = require("path");

// Export schema path for easy access
const schemaPath = path.join(__dirname, "prisma", "schema.prisma");

module.exports = {
  schemaPath,
  // Re-export utilities
  generateClient: require("./scripts/client"),
  runMigration: require("./scripts/migrate"),
};
