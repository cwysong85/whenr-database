# @whenr/whenr-database

Shared database package for the Whenr application. Contains the Prisma schema, migrations, and utilities used across all Whenr services.

## 🎯 Purpose

This package centralizes the database schema and provides a single source of truth for:

- Database models and relationships
- Prisma schema definitions
- Database migrations
- Type-safe database operations

## 📦 Installation

### As a Git Dependency

Add to your service's `package.json`:

```json
{
  "dependencies": {
    "@whenr/whenr-database": "git+ssh://git@github.com/cwysong85/whenr-database.git"
  }
}
```

Then install:

```bash
npm install
```

### Local Development

For local development, you can link the package:

```bash
# In whenr-database directory
npm link

# In your service directory
npm link @whenr/whenr-database
```

## 🚀 Usage

### 1. Generate Prisma Client

After installing the package, generate the Prisma client:

```bash
# Using the package script
npm run db:generate

# Or directly with Prisma
npx prisma generate --schema=node_modules/@whenr/whenr-database/prisma/schema.prisma
```

### 2. Run Migrations

```bash
# Development migrations
npm run db:migrate

# Production migrations
npm run db:migrate:deploy

# Reset database (development only)
npm run db:migrate:reset
```

### 3. Use in Your Code

```typescript
import { PrismaClient } from "@prisma/client";

const prisma = new PrismaClient();

// Use the client
const users = await prisma.user.findMany();
```

## 📁 Package Structure

```
whenr-database/
├── package.json              # Package configuration
├── README.md                 # This file
├── index.js                  # Main entry point
├── prisma/
│   ├── schema.prisma         # Prisma schema definition
│   └── migrations/           # Database migrations
└── scripts/
    ├── client.js             # Prisma client generator
    └── migrate.js            # Migration helper
```

## 🛠️ Available Scripts

### Package Scripts

```bash
npm run format          # Format the Prisma schema
npm run validate        # Validate the Prisma schema
npm run generate        # Generate Prisma client
npm run migrate:dev     # Run development migrations
npm run migrate:deploy  # Deploy production migrations
npm run migrate:reset   # Reset database (development)
npm run db:push         # Push schema to database
npm run db:studio       # Open Prisma Studio
```

### Service Integration Scripts

In your service's `package.json`, add these scripts:

```json
{
  "scripts": {
    "db:generate": "prisma generate --schema=node_modules/@whenr/whenr-database/prisma/schema.prisma",
    "db:migrate": "prisma migrate dev --schema=node_modules/@whenr/whenr-database/prisma/schema.prisma",
    "db:migrate:deploy": "prisma migrate deploy --schema=node_modules/@whenr/whenr-database/prisma/schema.prisma",
    "db:push": "prisma db push --schema=node_modules/@whenr/whenr-database/prisma/schema.prisma",
    "db:studio": "prisma studio --schema=node_modules/@whenr/whenr-database/prisma/schema.prisma"
  }
}
```

## 🗄️ Database Schema

The package includes a comprehensive Prisma schema with the following models:

### Core Models

- **User** - User accounts and authentication
- **Account** - OAuth provider accounts (NextAuth.js)
- **Session** - User sessions (NextAuth.js)
- **UserPreference** - User settings and preferences

### Group Management

- **Group** - Groups with icons and settings
- **GroupMember** - Group membership with roles
- **GroupActivity** - Activity feed for groups
- **GroupInvite** - Email-based group invitations

### Event Coordination

- **EventProposal** - Event proposals within groups
- **EventVote** - Voting on event proposals
- **CachedEvent** - Cached external events

### Communication

- **ChatMessage** - Group and proposal chat messages

### Calendar Integration (Future)

- **CalendarConnection** - Connected calendar accounts
- **SharedCalendar** - Individual calendars with sharing

## 🔧 Development Workflow

### 1. Schema Changes

When you need to modify the database schema:

1. Edit `prisma/schema.prisma` in this package
2. Create a migration: `npm run migrate:dev`
3. Commit and push changes to the repository
4. Update services to pull the latest version

### 2. Service Updates

When the database package is updated:

1. Pull the latest version: `npm update @whenr/whenr-database`
2. Generate new client: `npm run db:generate`
3. Run any new migrations: `npm run db:migrate`

### 3. Adding New Models

To add new database models:

1. Edit `prisma/schema.prisma`
2. Run `npm run format` to format the schema
3. Create migration: `npm run migrate:dev`
4. Test the changes locally
5. Commit and push to repository

## 🚨 Important Notes

### Environment Variables

Each service must have these environment variables:

```bash
DATABASE_URL=postgresql://user:password@localhost:5432/database
DIRECT_URL=postgresql://user:password@localhost:5432/database
```

### Schema Changes

- **Breaking changes** require coordination across all services
- **Always test migrations** in development before deploying
- **Backup production data** before running migrations
- **Coordinate deployments** to avoid schema conflicts

### Version Management

- Use semantic versioning for the package
- Tag releases in the repository
- Document breaking changes in release notes
- Consider migration strategies for major changes

## 🔗 Integration with Services

### whenr-backend

```json
{
  "dependencies": {
    "@whenr/whenr-database": "git+ssh://git@github.com/cwysong85/whenr-database.git"
  }
}
```

### whenr-realtime-services

```json
{
  "dependencies": {
    "@whenr/whenr-database": "git+ssh://git@github.com/cwysong85/whenr-database.git"
  }
}
```

### whenr (frontend)

```json
{
  "dependencies": {
    "@whenr/whenr-database": "git+ssh://git@github.com/cwysong85/whenr-database.git"
  }
}
```

## 🧪 Testing

### Local Testing

```bash
# Test schema validation
npm run validate

# Test client generation
npm run generate

# Test migrations
npm run migrate:dev
```

### Integration Testing

```bash
# In your service directory
npm install @whenr/whenr-database
npm run db:generate
npm run db:migrate

# Test database operations
npm run db:studio
```

## 📚 Additional Resources

- [Prisma Documentation](https://www.prisma.io/docs/)
- [PostgreSQL Documentation](https://www.postgresql.org/docs/)
- [Database Migration Best Practices](https://www.prisma.io/docs/guides/database/developing-with-prisma-migrate)

## 🆘 Troubleshooting

### Common Issues

**Schema not found:**

```bash
# Ensure the package is installed
npm install @whenr/whenr-database

# Check the schema path
ls node_modules/@whenr/whenr-database/prisma/schema.prisma
```

**Migration conflicts:**

```bash
# Reset development database
npm run db:migrate:reset

# Or resolve conflicts manually
npm run db:migrate:resolve
```

**Client generation fails:**

```bash
# Check Prisma installation
npx prisma --version

# Regenerate client
npm run db:generate
```

### Getting Help

1. Check the [Prisma documentation](https://www.prisma.io/docs/)
2. Review the schema in `prisma/schema.prisma`
3. Test migrations in a development environment
4. Check environment variables are set correctly

---

**@whenr/whenr-database** - Centralized database schema for Whenr 🗄️
