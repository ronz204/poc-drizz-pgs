import { assertUuid, UniqueUUID } from "@core/common-domain";
import { uuidv7 } from "uuidv7";

export class ServiceId extends UniqueUUID {
	private constructor(value: string) {
		super(value);
	}

	public static generate(): ServiceId {
		return new ServiceId(uuidv7());
	}

	public static from(value: string): ServiceId {
		assertUuid(value, "ServiceId");
		return new ServiceId(value);
	}
}
