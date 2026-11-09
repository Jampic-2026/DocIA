import { Module } from "@nestjs/common";
import { ConfigModule } from "@nestjs/config";
import { configuration } from "./config/configuration";
import { validateEnv } from "./config/env.validation";
import { DatabaseModule } from "./database/database.module";
import { AppHealthModule } from "./modules/app-health/app-health.module";
import { AuthModule } from "./modules/auth/auth.module";
import { UsersModule } from "./modules/users/users.module";
import { PeopleModule } from "./modules/people/people.module";
import { PatientsModule } from "./modules/patients/patients.module";
import { ConsentsModule } from "./modules/consents/consents.module";
import { ProfessionalsModule } from "./modules/professionals/professionals.module";
import { ClinicalRecordsModule } from "./modules/clinical-records/clinical-records.module";
import { EmergenciesModule } from "./modules/emergencies/emergencies.module";
import { AiModule } from "./modules/ai/ai.module";
import { AppointmentsModule } from "./modules/appointments/appointments.module";
import { PrescriptionsModule } from "./modules/prescriptions/prescriptions.module";
import { CatalogModule } from "./modules/catalog/catalog.module";
import { CoinsModule } from "./modules/coins/coins.module";
import { PaymentsModule } from "./modules/payments/payments.module";
import { BenefitsModule } from "./modules/benefits/benefits.module";
import { PartnersModule } from "./modules/partners/partners.module";
import { HomeServicesModule } from "./modules/home-services/home-services.module";
import { DeliveriesModule } from "./modules/deliveries/deliveries.module";
import { IncidentsModule } from "./modules/incidents/incidents.module";
import { HumanResourcesModule } from "./modules/human-resources/human-resources.module";
import { NotificationsModule } from "./modules/notifications/notifications.module";
import { AdministrationModule } from "./modules/administration/administration.module";
import { AuditModule } from "./modules/audit/audit.module";
import { IntegrationsModule } from "./modules/integrations/integrations.module";
import { MapsModule } from "./modules/maps/maps.module";
import { FilesModule } from "./modules/files/files.module";
import { OperationsModule } from "./modules/operations/operations.module";
import { ThrottlerModule } from "@nestjs/throttler";

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
      envFilePath: process.env.DOCIA_SITES_FILE
        ? [process.env.DOCIA_SITES_FILE, ".env"]
        : ".env",
      load: [configuration],
      validate: validateEnv,
    }),
    ThrottlerModule.forRoot([
      {
        ttl: 60_000,
        limit: 120,
      },
    ]),
    DatabaseModule,
    AppHealthModule,
    AuthModule,
    UsersModule,
    PeopleModule,
    PatientsModule,
    ConsentsModule,
    ProfessionalsModule,
    ClinicalRecordsModule,
    EmergenciesModule,
    AiModule,
    AppointmentsModule,
    PrescriptionsModule,
    CatalogModule,
    CoinsModule,
    PaymentsModule,
    BenefitsModule,
    PartnersModule,
    HomeServicesModule,
    DeliveriesModule,
    IncidentsModule,
    HumanResourcesModule,
    NotificationsModule,
    AdministrationModule,
    AuditModule,
    IntegrationsModule,
    MapsModule,
    FilesModule,
    OperationsModule,
  ],
})
export class AppModule {}
