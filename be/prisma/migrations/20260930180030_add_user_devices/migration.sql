/*
  Warnings:

  - You are about to drop the column `paymentRef` on the `user_subscriptions` table. All the data in the column will be lost.
  - You are about to drop the column `payosOrderCode` on the `user_subscriptions` table. All the data in the column will be lost.
  - You are about to drop the column `payosPaymentLinkId` on the `user_subscriptions` table. All the data in the column will be lost.

*/
-- DropIndex
DROP INDEX `user_subscriptions_payosOrderCode_key` ON `user_subscriptions`;

-- AlterTable
ALTER TABLE `family_groups` MODIFY `deletedAt` DATETIME(3) NULL;

-- AlterTable
ALTER TABLE `family_members` MODIFY `joinedAt` DATETIME(3) NULL;

-- AlterTable
ALTER TABLE `payment_transactions` MODIFY `qrCode` TEXT NULL,
    MODIFY `expiredAt` DATETIME(3) NULL,
    MODIFY `paidAt` DATETIME(3) NULL;

-- AlterTable
ALTER TABLE `user_subscriptions` DROP COLUMN `paymentRef`,
    DROP COLUMN `payosOrderCode`,
    DROP COLUMN `payosPaymentLinkId`,
    MODIFY `quotaResetAt` DATETIME(3) NULL;

-- CreateTable
CREATE TABLE `user_devices` (
    `id` CHAR(36) NOT NULL,
    `userId` CHAR(36) NOT NULL,
    `fcmToken` VARCHAR(512) NOT NULL,
    `platform` VARCHAR(20) NOT NULL,
    `deviceName` VARCHAR(100) NULL,
    `isActive` BOOLEAN NOT NULL DEFAULT true,
    `createdAt` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updatedAt` DATETIME(3) NOT NULL,

    UNIQUE INDEX `user_devices_fcmToken_key`(`fcmToken`),
    INDEX `user_devices_userId_isActive_idx`(`userId`, `isActive`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateIndex
CREATE INDEX `payment_transactions_payosOrderCode_idx` ON `payment_transactions`(`payosOrderCode`);

-- AddForeignKey
ALTER TABLE `user_devices` ADD CONSTRAINT `user_devices_userId_fkey` FOREIGN KEY (`userId`) REFERENCES `users`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `payment_transactions` ADD CONSTRAINT `payment_transactions_planId_fkey` FOREIGN KEY (`planId`) REFERENCES `subscription_plans`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `payment_transactions` ADD CONSTRAINT `payment_transactions_userId_fkey` FOREIGN KEY (`userId`) REFERENCES `users`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `family_groups` ADD CONSTRAINT `family_groups_ownerId_fkey` FOREIGN KEY (`ownerId`) REFERENCES `users`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `family_members` ADD CONSTRAINT `family_members_familyGroupId_fkey` FOREIGN KEY (`familyGroupId`) REFERENCES `family_groups`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `family_members` ADD CONSTRAINT `family_members_userId_fkey` FOREIGN KEY (`userId`) REFERENCES `users`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;
