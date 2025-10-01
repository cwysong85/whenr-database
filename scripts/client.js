#!/usr/bin/env node

/**
 * Prisma Client Generator
 *
 * This script generates the Prisma client for the shared database package.
 * It should be run from each service that uses the database.
 */

const { execSync } = require("child_process");
const path = require("path");

const schemaPath = path.join(__dirname, "..", "prisma", "schema.prisma");

console.log("🔧 Generating Prisma client...");
console.log(`📁 Schema path: ${schemaPath}`);

try {
  execSync(`npx prisma generate --schema="${schemaPath}"`, {
    stdio: "inherit",
    cwd: process.cwd(),
  });

  console.log("✅ Prisma client generated successfully!");
  console.log("📦 Client available at: node_modules/.prisma/client");
} catch (error) {
  console.error("❌ Failed to generate Prisma client:", error.message);
  process.exit(1);
}
