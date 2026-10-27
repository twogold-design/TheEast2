extends RefCounted
## Rebuilt on map edits, never by decorative NPCs or every render frame.
## Bridge cells participate individually, so crossing a river costs real length.

static func build_records(game: Node) -> Array:
	var road_cells := {}
	for cell in game.roads:
		road_cells[cell] = true
	for z in range(game.VILLAGE_ROAD_MIN_Z, game.VILLAGE_ROAD_MAX_Z + 1):
		road_cells[Vector2i(game.VILLAGE_ROAD_X, z)] = true
	for bridge in game.NPC_BRIDGES:
		for x in range(int(bridge.water_min_x), int(bridge.water_max_x) + 1):
			road_cells[Vector2i(x, int(bridge.row))] = true
	var home_dist := _distances([Vector2i(game.VILLAGE_ROAD_X, game.VILLAGE_ROAD_MIN_Z)], road_cells)
	var records: Array = []
	var entrances := {}
	var docks := {}
	for b in game.buildings:
		var id := str(b.id)
		var starts: Array = []
		var connected := false
		var entrance_distance := 100000
		for cell in game.building_boundary_cells(b):
			if road_cells.has(cell) and not game.is_water_cell(cell):
				starts.append(cell)
				if home_dist.has(cell):
					connected = true
					entrance_distance = mini(entrance_distance, int(home_dist[cell]))
		entrances[id] = starts
		var landscape := _landscape(game, b)
		var entry := {"id": id, "type": str(b.type), "enabled": bool(b.get("enabled", true)), "connected": connected, "region": str(game.region_level_for_cell(b.cell)), "road_component": "main" if connected else "isolated:" + id, "road_distance": entrance_distance if connected else 0, "road_links": {}, "water_links": {}, "service_targets": {}, "scenery_score": landscape.size(), "landscape_dimensions": landscape}
		records.append(entry)
		if b.type == "dock":
			var water: Array = []
			for cell in game.building_footprint_cells("dock", b.cell, game.record_footprint(b)):
				if game.is_water_cell(cell):
					water.append(cell)
			docks[id] = water
	for source in records:
		var distances := _distances(entrances[source.id], road_cells)
		for dest in records:
			if source.id == dest.id:
				continue
			var shortest := 100000
			for cell in entrances[dest.id]:
				if distances.has(cell):
					shortest = mini(shortest, int(distances[cell]) + 2)
			if shortest < 100000:
				source.road_links[dest.id] = shortest
				if dest.type == "house":
					source.service_targets[dest.id] = shortest
	var water_cells := {}
	if docks.size() > 1:
		for z in range(game.GRID_SIZE):
			for x in range(game.GRID_SIZE):
				var cell := Vector2i(x, z)
				if game.is_water_cell(cell) and game.region_level_for_cell(cell) <= game.map_region_level:
					water_cells[cell] = true
		for source in records:
			if source.type != "dock":
				continue
			var distances := _distances(docks[source.id], water_cells)
			for other_id in docks:
				if other_id == source.id:
					continue
				var shortest := 100000
				for cell in docks[other_id]:
					if distances.has(cell):
						shortest = mini(shortest, int(distances[cell]) + 1)
				if shortest < 100000:
					source.water_links[other_id] = shortest
	return records

static func _distances(starts: Array, allowed: Dictionary) -> Dictionary:
	var queue: Array = []
	var distances := {}
	for cell in starts:
		if allowed.has(cell) and not distances.has(cell):
			queue.append(cell)
			distances[cell] = 0
	var index := 0
	while index < queue.size():
		var cell: Vector2i = queue[index]
		index += 1
		for delta in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var neighbor: Vector2i = cell + delta
			if allowed.has(neighbor) and not distances.has(neighbor):
				distances[neighbor] = int(distances[cell]) + 1
				queue.append(neighbor)
	return distances

static func _landscape(game: Node, b: Dictionary) -> Array:
	var dimensions: Array = []
	if b.type not in ["pavilion", "garden"]:
		return dimensions
	var trees := 0
	var banks := 0
	var open_cells := 0
	var center: Vector2i = b.cell + game.record_footprint(b) / 2
	for z in range(center.y - 6, center.y + 7):
		for x in range(center.x - 6, center.x + 7):
			var cell := Vector2i(x, z)
			if not game.is_playable_cell(cell) or absi(x-center.x) + absi(z-center.y) > 6:
				continue
			if game.has_scenery_tree(cell):
				trees += 1
			elif not game.is_water_cell(cell) and not game.occupied.has(cell) and not game.roads.has(cell):
				open_cells += 1
			if game.is_farm_cell(cell):
				banks += 1
	if trees >= 4:
		dimensions.append("shade")
	if banks >= 4:
		dimensions.append("waterfront")
	if open_cells >= 4 or b.type == "garden":
		dimensions.append("green")
	return dimensions
