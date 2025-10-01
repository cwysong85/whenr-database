#!/usr/bin/env node

/**
 * Database Migration Helper
 *
 * This script helps run migrations for the shared database package.
 * It should be run from each service that uses the database.
 */

const { execSync } = require("child_process");
const path = require("path");

const schemaPath = path.join(__dirname, "..", "prisma", "schema.prisma");

const command = process.argv[2] || "dev";
const args = process.argv.slice(3);

console.log("🔄 Running database migration...");
console.log(`📁 Schema path: ${schemaPath}`);
console.log(`🎯 Command: migrate ${command}`);

const validCommands = ["dev", "deploy", "reset", "status", "resolve"];

if (!validCommands.includes(command)) {
  console.error(`❌ Invalid command: ${command}`);
  console.error(`Valid commands: ${validCommands.join(", ")}`);
  process.exit(1);
}

try {
  const fullCommand = `npx prisma migrate ${command} --schema="${schemaPath}" ${args.join(
    " "
  )}`;
  console.log(`🚀 Executing: ${fullCommand}`);

  execSync(fullCommand, {
    stdio: "inherit",
    cwd: process.cwd(),
  });

  console.log("✅ Migration completed successfully!");
} catch (error) {
  console.error("❌ Migration failed:", error.message);
  process.exit(1);
}
