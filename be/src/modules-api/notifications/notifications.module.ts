import { Module } from '@nestjs/common';
import { ScheduleModule } from '@nestjs/schedule';
import { ClientsModule, Transport } from '@nestjs/microservices';
import { NotificationsController } from './notifications.controller';
import { NotificationsService } from './notifications.service';
import { NotificationCronService } from './notification-cron.service';
import { PrismaModule } from 'src/modules-system/prisma/prisma.module';
import { FcmModule } from 'src/modules-system/fcm/fcm.module';
import { RABBIT_MQ_URL } from 'src/common/constants/app.constant';

@Module({
  imports: [
    PrismaModule,
    FcmModule,
    ScheduleModule.forRoot(),
    ClientsModule.register([
      {
        name: 'EMAIL_SERVICE',
        transport: Transport.RMQ,
        options: {
          urls: [RABBIT_MQ_URL ?? 'amqp://user:12345@localhost:5673'],
          queue: 'email_queue',
          queueOptions: { durable: true },
        },
      },
    ]),
  ],
  controllers: [NotificationsController],
  providers: [NotificationsService, NotificationCronService],
  exports: [NotificationsService, NotificationCronService],
})
export class NotificationsModule {}
