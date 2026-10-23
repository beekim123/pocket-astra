class_name FieldJournal
extends RefCounted
## Page calculations remain independent from player progress and UI widgets.

const PAGE_SIZE: int = 8

static func page_count(total: int) -> int:
	return maxi(1, ceili(float(maxi(total, 0)) / float(PAGE_SIZE)))

static func ids_on_page(page: int, total: int) -> Array[int]:
	var result: Array[int] = []
	var first: int = clampi(page, 0, page_count(total) - 1) * PAGE_SIZE
	for id: int in range(first, mini(maxi(total, 0), first + PAGE_SIZE)):
		result.append(id)
	return result
