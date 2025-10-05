/*
  Warnings:

  - A unique constraint covering the columns `[ablyMessageId]` on the table `chat_messages` will be added. If there are existing duplicate values, this will fail.

*/
-- CreateEnum
CREATE TYPE "ActivityType" AS ENUM ('GROUP_CREATED', 'MEMBER_JOINED', 'MEMBER_LEFT', 'EVENT_PROPOSED', 'EVENT_APPROVED', 'EVENT_CANCELLED', 'GROUP_UPDATED');

-- AlterTable
ALTER TABLE "chat_messages" ADD COLUMN     "ablyMessageId" TEXT;

-- CreateTable
CREATE TABLE "group_activities" (
    "id" TEXT NOT NULL,
    "groupId" TEXT NOT NULL,
    "userId" TEXT,
    "activityType" "ActivityType" NOT NULL,
    "title" TEXT NOT NULL,
    "description" TEXT,
    "metadata" JSONB,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "group_activities_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "group_invites" (
    "id" TEXT NOT NULL,
    "groupId" TEXT NOT NULL,
    "invitedBy" TEXT NOT NULL,
    "invitedEmail" TEXT NOT NULL,
    "inviteCode" TEXT NOT NULL,
    "expiresAt" TIMESTAMP(3) NOT NULL,
    "isUsed" BOOLEAN NOT NULL DEFAULT false,
    "usedAt" TIMESTAMP(3),
    "usedBy" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "group_invites_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "beta_signups" (
    "id" TEXT NOT NULL,
    "email" TEXT NOT NULL,
    "ipAddress" TEXT,
    "userAgent" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "beta_signups_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "group_invites_inviteCode_key" ON "group_invites"("inviteCode");

-- CreateIndex
CREATE UNIQUE INDEX "beta_signups_email_key" ON "beta_signups"("email");

-- CreateIndex
CREATE UNIQUE INDEX "chat_messages_ablyMessageId_key" ON "chat_messages"("ablyMessageId");

-- AddForeignKey
ALTER TABLE "group_activities" ADD CONSTRAINT "group_activities_groupId_fkey" FOREIGN KEY ("groupId") REFERENCES "groups"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "group_activities" ADD CONSTRAINT "group_activities_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "group_invites" ADD CONSTRAINT "group_invites_groupId_fkey" FOREIGN KEY ("groupId") REFERENCES "groups"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "group_invites" ADD CONSTRAINT "group_invites_invitedBy_fkey" FOREIGN KEY ("invitedBy") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "group_invites" ADD CONSTRAINT "group_invites_usedBy_fkey" FOREIGN KEY ("usedBy") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;
