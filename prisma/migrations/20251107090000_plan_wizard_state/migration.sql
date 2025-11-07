-- CreateEnum
CREATE TYPE "PlanWizardMode" AS ENUM ('EVENT', 'MANUAL');

-- CreateEnum
CREATE TYPE "PlanWizardStep" AS ENUM (
    'MODE',
    'EVENT_SELECTION',
    'DATES',
    'TRANSPORTATION',
    'LODGING',
    'DINING',
    'SUMMARY',
    'COMPLETE'
);

-- CreateTable
CREATE TABLE "plan_wizard_states" (
    "id" TEXT NOT NULL,
    "planId" TEXT NOT NULL,
    "mode" "PlanWizardMode" NOT NULL,
    "currentStep" "PlanWizardStep",
    "completedSteps" "PlanWizardStep"[] DEFAULT ARRAY[]::"PlanWizardStep"[],
    "responses" JSONB,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "plan_wizard_states_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "plan_wizard_states_planId_key" ON "plan_wizard_states"("planId");

-- AddForeignKey
ALTER TABLE "plan_wizard_states" ADD CONSTRAINT "plan_wizard_states_planId_fkey" FOREIGN KEY ("planId") REFERENCES "plans"("id") ON DELETE CASCADE ON UPDATE CASCADE;

