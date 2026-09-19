CREATE TYPE "core"."incident_severity" AS ENUM('minor', 'major', 'critical');--> statement-breakpoint
CREATE TYPE "core"."incident_status" AS ENUM('investigating', 'identified', 'monitoring', 'resolved');--> statement-breakpoint
CREATE TYPE "core"."tenant_plan" AS ENUM('pro', 'free', 'enterprise');--> statement-breakpoint
CREATE TABLE "core"."incident_services" (
	"tenant_id" uuid NOT NULL,
	"incident_id" uuid,
	"service_id" uuid,
	CONSTRAINT "incident_services_pkey" PRIMARY KEY("incident_id","service_id")
);
--> statement-breakpoint
ALTER TABLE "core"."incident_services" ENABLE ROW LEVEL SECURITY;--> statement-breakpoint
CREATE TABLE "core"."incident_updates" (
	"id" uuid PRIMARY KEY,
	"tenant_id" uuid NOT NULL,
	"incident_id" uuid NOT NULL,
	"status" "core"."incident_status" NOT NULL,
	"message" text NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
ALTER TABLE "core"."incident_updates" ENABLE ROW LEVEL SECURITY;--> statement-breakpoint
CREATE TABLE "core"."incidents" (
	"id" uuid PRIMARY KEY,
	"tenant_id" uuid NOT NULL,
	"title" text NOT NULL,
	"status" "core"."incident_status" DEFAULT 'investigating'::"core"."incident_status" NOT NULL,
	"severity" "core"."incident_severity" NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "incidents_tenant_id_id_unique" UNIQUE("tenant_id","id")
);
--> statement-breakpoint
ALTER TABLE "core"."incidents" ENABLE ROW LEVEL SECURITY;--> statement-breakpoint
CREATE TABLE "core"."services" (
	"id" uuid PRIMARY KEY,
	"tenant_id" uuid NOT NULL,
	"name" text NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "services_tenant_id_id_unique" UNIQUE("tenant_id","id"),
	CONSTRAINT "services_tenant_id_name_unique" UNIQUE("tenant_id","name")
);
--> statement-breakpoint
ALTER TABLE "core"."services" ENABLE ROW LEVEL SECURITY;--> statement-breakpoint
CREATE TABLE "core"."subscribers" (
	"id" uuid PRIMARY KEY,
	"tenant_id" uuid NOT NULL,
	"email" text NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "subscribers_tenant_id_email_unique" UNIQUE("tenant_id","email")
);
--> statement-breakpoint
ALTER TABLE "core"."subscribers" ENABLE ROW LEVEL SECURITY;--> statement-breakpoint
CREATE TABLE "core"."tenants" (
	"id" uuid PRIMARY KEY,
	"slug" text NOT NULL UNIQUE,
	"name" text NOT NULL,
	"plan" "core"."tenant_plan" NOT NULL,
	"max_services" integer NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "max_services_positive" CHECK ("max_services" > 0)
);
--> statement-breakpoint
CREATE INDEX "incident_services_service_id_tenant_id_idx" ON "core"."incident_services" ("service_id","tenant_id");--> statement-breakpoint
CREATE INDEX "incident_updates_incident_id_created_at_idx" ON "core"."incident_updates" ("incident_id","created_at");--> statement-breakpoint
CREATE INDEX "incidents_tenant_id_status_idx" ON "core"."incidents" ("tenant_id","status");--> statement-breakpoint
CREATE INDEX "incidents_tenant_id_created_at_idx" ON "core"."incidents" ("tenant_id","created_at" DESC NULLS LAST);--> statement-breakpoint
ALTER TABLE "core"."incident_services" ADD CONSTRAINT "incident_services_tenant_id_incident_id_fk" FOREIGN KEY ("tenant_id","incident_id") REFERENCES "core"."incidents"("tenant_id","id");--> statement-breakpoint
ALTER TABLE "core"."incident_services" ADD CONSTRAINT "incident_services_tenant_id_service_id_fk" FOREIGN KEY ("tenant_id","service_id") REFERENCES "core"."services"("tenant_id","id");--> statement-breakpoint
ALTER TABLE "core"."incident_updates" ADD CONSTRAINT "incident_updates_tenant_id_incident_id_fk" FOREIGN KEY ("tenant_id","incident_id") REFERENCES "core"."incidents"("tenant_id","id");--> statement-breakpoint
ALTER TABLE "core"."incidents" ADD CONSTRAINT "incidents_tenant_id_tenants_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "core"."tenants"("id");--> statement-breakpoint
ALTER TABLE "core"."services" ADD CONSTRAINT "services_tenant_id_tenants_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "core"."tenants"("id");--> statement-breakpoint
ALTER TABLE "core"."subscribers" ADD CONSTRAINT "subscribers_tenant_id_tenants_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "core"."tenants"("id");--> statement-breakpoint
CREATE POLICY "tenant_isolation" ON "core"."incident_services" AS RESTRICTIVE FOR ALL TO "runner" USING ("core"."incident_services"."tenant_id" = current_setting('app.tenant_id', true)::uuid) WITH CHECK ("core"."incident_services"."tenant_id" = current_setting('app.tenant_id', true)::uuid);--> statement-breakpoint
CREATE POLICY "tenant_isolation" ON "core"."incident_updates" AS RESTRICTIVE FOR ALL TO "runner" USING ("core"."incident_updates"."tenant_id" = current_setting('app.tenant_id', true)::uuid) WITH CHECK ("core"."incident_updates"."tenant_id" = current_setting('app.tenant_id', true)::uuid);--> statement-breakpoint
CREATE POLICY "tenant_isolation" ON "core"."incidents" AS RESTRICTIVE FOR ALL TO "runner" USING ("core"."incidents"."tenant_id" = current_setting('app.tenant_id', true)::uuid) WITH CHECK ("core"."incidents"."tenant_id" = current_setting('app.tenant_id', true)::uuid);--> statement-breakpoint
CREATE POLICY "tenant_isolation" ON "core"."services" AS RESTRICTIVE FOR ALL TO "runner" USING ("core"."services"."tenant_id" = current_setting('app.tenant_id', true)::uuid) WITH CHECK ("core"."services"."tenant_id" = current_setting('app.tenant_id', true)::uuid);--> statement-breakpoint
CREATE POLICY "tenant_isolation" ON "core"."subscribers" AS RESTRICTIVE FOR ALL TO "runner" USING ("core"."subscribers"."tenant_id" = current_setting('app.tenant_id', true)::uuid) WITH CHECK ("core"."subscribers"."tenant_id" = current_setting('app.tenant_id', true)::uuid);