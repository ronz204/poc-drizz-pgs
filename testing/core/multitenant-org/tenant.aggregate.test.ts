import {
	PlanDowngradeConflictError,
	ServiceCapExceededError,
	Tenant,
	TenantId,
} from "@core/multitenant-org";
import { buildTenant } from "@tests/utils/fixtures/tenant.fixture";
import { describe, expect, it } from "vitest";

describe("Tenant.create", () => {
	it("creates a Tenant with the plan's mapped service cap", () => {
		const tenant = Tenant.create("acme", "pro");

		expect(tenant.slug).toBe("acme");
		expect(tenant.plan).toBe("pro");
		expect(tenant.serviceCap).toBe(15);
	});
});

describe("Tenant.assertCanRegisterService", () => {
	it("allows registering a Service while under the cap", () => {
		const tenant = buildTenant("free");

		expect(() => tenant.assertCanRegisterService(2)).not.toThrow();
	});

	it("rejects registering a Service once at the cap", () => {
		const tenant = buildTenant("free");

		expect(() => tenant.assertCanRegisterService(3)).toThrow(
			ServiceCapExceededError,
		);
	});
});

describe("Tenant.reconstitute", () => {
	it("rebuilds a Tenant from a snapshot without re-deriving serviceCap from plan", () => {
		const id = TenantId.generate().value;

		const tenant = Tenant.reconstitute({
			id,
			slug: "acme",
			plan: "free",
			serviceCap: 999,
		});

		expect(tenant.id.value).toBe(id);
		expect(tenant.plan).toBe("free");
		expect(tenant.serviceCap).toBe(999);
	});
});

describe("Tenant.changePlan", () => {
	it("returns a new Tenant with the new plan's mapped service cap, leaving the original unchanged", () => {
		const tenant = buildTenant("free");

		const upgraded = tenant.changePlan("pro", 2);

		expect(upgraded).not.toBe(tenant);
		expect(upgraded.plan).toBe("pro");
		expect(upgraded.serviceCap).toBe(15);
		expect(tenant.plan).toBe("free");
		expect(tenant.serviceCap).toBe(3);
	});

	it("rejects a downgrade below the current Service count and leaves the Tenant unchanged", () => {
		const tenant = buildTenant("pro");

		expect(() => tenant.changePlan("free", 4)).toThrow(
			PlanDowngradeConflictError,
		);
		expect(tenant.plan).toBe("pro");
		expect(tenant.serviceCap).toBe(15);
	});
});
