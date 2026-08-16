-- CreateSchema
CREATE SCHEMA IF NOT EXISTS "public";

-- CreateEnum
CREATE TYPE "ChallengeMetric" AS ENUM ('STREAK', 'TOTAL_RETENTION_SEC', 'SESSION_COUNT');

-- CreateTable
CREATE TABLE "User" (
    "id" TEXT NOT NULL,
    "email" TEXT NOT NULL,
    "passwordHash" TEXT NOT NULL,
    "profileName" TEXT,
    "fcmToken" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "User_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Session" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "levelKey" TEXT NOT NULL,
    "timestamp" TIMESTAMP(3) NOT NULL,
    "durationSec" INTEGER NOT NULL,
    "rounds" INTEGER NOT NULL,
    "retentionSec" INTEGER NOT NULL,
    "rpeScore" INTEGER,
    "xpEarned" INTEGER NOT NULL,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "Session_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "FreedivingLog" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "tableType" TEXT NOT NULL,
    "pbUsedSec" INTEGER NOT NULL,
    "roundsJson" TEXT NOT NULL,
    "roundsCompleted" INTEGER NOT NULL,
    "durationSec" INTEGER NOT NULL,
    "timestamp" TIMESTAMP(3) NOT NULL,
    "rpeScore" INTEGER,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "FreedivingLog_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "CustomPreset" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "inhaleSec" INTEGER NOT NULL,
    "holdInSec" INTEGER NOT NULL,
    "exhaleSec" INTEGER NOT NULL,
    "holdOutSec" INTEGER NOT NULL,
    "cycles" INTEGER NOT NULL,
    "rounds" INTEGER NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    "deletedAt" TIMESTAMP(3),

    CONSTRAINT "CustomPreset_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "CustomFreedivingPreset" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "startApneaSec" INTEGER NOT NULL,
    "endApneaSec" INTEGER NOT NULL,
    "startRestSec" INTEGER NOT NULL,
    "endRestSec" INTEGER NOT NULL,
    "rounds" INTEGER NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    "deletedAt" TIMESTAMP(3),

    CONSTRAINT "CustomFreedivingPreset_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ProfileState" (
    "userId" TEXT NOT NULL,
    "verifiedPbSec" INTEGER,
    "verifiedPbAt" TIMESTAMP(3),
    "safetyAcknowledgedAt" TIMESTAMP(3),
    "wimHofCurrentLevelKey" TEXT,
    "wimHofCurrentLevelSetAt" TIMESTAMP(3),
    "availableWeekdaysMask" INTEGER,
    "availableHourStart" INTEGER,
    "availableHourEnd" INTEGER,
    "allowMultiplePerDay" BOOLEAN,
    "dailyReminderEnabled" BOOLEAN,
    "clientUpdatedAt" TIMESTAMP(3) NOT NULL,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "ProfileState_pkey" PRIMARY KEY ("userId")
);

-- CreateTable
CREATE TABLE "Challenge" (
    "id" TEXT NOT NULL,
    "key" TEXT NOT NULL,
    "title" TEXT NOT NULL,
    "description" TEXT NOT NULL,
    "metric" "ChallengeMetric" NOT NULL,
    "startsAt" TIMESTAMP(3) NOT NULL,
    "endsAt" TIMESTAMP(3) NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "Challenge_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ChallengeParticipant" (
    "id" TEXT NOT NULL,
    "challengeId" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "joinedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "ChallengeParticipant_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "User_email_key" ON "User"("email");

-- CreateIndex
CREATE INDEX "Session_userId_timestamp_idx" ON "Session"("userId", "timestamp");

-- CreateIndex
CREATE INDEX "FreedivingLog_userId_timestamp_idx" ON "FreedivingLog"("userId", "timestamp");

-- CreateIndex
CREATE UNIQUE INDEX "Challenge_key_key" ON "Challenge"("key");

-- CreateIndex
CREATE UNIQUE INDEX "ChallengeParticipant_challengeId_userId_key" ON "ChallengeParticipant"("challengeId", "userId");

-- AddForeignKey
ALTER TABLE "Session" ADD CONSTRAINT "Session_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "FreedivingLog" ADD CONSTRAINT "FreedivingLog_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "CustomPreset" ADD CONSTRAINT "CustomPreset_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "CustomFreedivingPreset" ADD CONSTRAINT "CustomFreedivingPreset_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ProfileState" ADD CONSTRAINT "ProfileState_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ChallengeParticipant" ADD CONSTRAINT "ChallengeParticipant_challengeId_fkey" FOREIGN KEY ("challengeId") REFERENCES "Challenge"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ChallengeParticipant" ADD CONSTRAINT "ChallengeParticipant_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

