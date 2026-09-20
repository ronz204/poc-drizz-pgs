import { InvalidIdentifierError } from "@core/common-domain";
import { Service } from "@core/multitenant-org/contexts/service/service.aggregate";
import { DuplicateServiceNameError } from "@core/multitenant-org/contexts/service/service.errors";
import {
	INVALID_UUID,
	validUuid,
} from "@tests/utils/fixtures/identifier.fixture";
import { buildTenant } from "@tests/utils/fixtures/tenant.fixture";
import { describe, expect, it } from "vitest";

describe("Service.create", () => {
	it("registers a Service when the Tenant is under its cap", () => {
		const tenant = buildTenant("free");

		expect(() => tenant.assertCanRegisterService(0)).not.toThrow();
		const service = Service.create(tenant, "status-api", []);

		expect(service.tenantId.equals(tenant.id)).toBe(true);
		expect(service.name).toBe("status-api");
	});

	it("rejects a Service name that duplicates another Service's name within the same Tenant", () => {
		const tenant = buildTenant("free");

		expect(() => Service.create(tenant, "status-api", ["status-api"])).toThrow(
			DuplicateServiceNameError,
		);
	});
});

describe("Service.reconstitute", () => {
	it("rebuilds a Service from a snapshot without checking the referenced Tenant exists", () => {
		const tenantId = validUuid();

		const service = Service.reconstitute({
			id: validUuid(),
			tenantId,
			name: "status-api",
		});

		expect(service.tenantId.value).toBe(tenantId);
		expect(service.name).toBe("status-api");
	});

	it("rejects an invalid tenantId in the snapshot", () => {
		expect(() =>
			Service.reconstitute({
				id: validUuid(),
				tenantId: INVALID_UUID,
				name: "status-api",
			}),
		).toThrow(InvalidIdentifierError);
	});
});
