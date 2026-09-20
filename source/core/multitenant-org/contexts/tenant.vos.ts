import { assertUuid, UniqueUUID } from "@core/common-domain";
import { uuidv7 } from "uuidv7";

export class TenantId extends UniqueUUID {
	private constructor(value: string) {
		super(value);
	}

	public static generate(): TenantId {
		return new TenantId(uuidv7());
	}

	public static from(value: string): TenantId {
		assertUuid(value, "TenantId");
		return new TenantId(value);
	}
}
