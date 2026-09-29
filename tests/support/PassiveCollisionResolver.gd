extends CollisionResolver


# Test-only resolver for suites that deliberately disconnect Board.orb_contact.
func sweep_resting_contacts() -> int:
	return flush()
