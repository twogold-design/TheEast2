import * as THREE from 'three';
import './style.css';

type BuildingType = 'house' | 'lumber' | 'farm' | 'warehouse' | 'workshop';
type Building = { id: number; type: BuildingType; x: number; z: number; mesh: THREE.Group };

const GRID = 20;
const TILE = 2;
const HALF = GRID / 2;
const defs: Record<BuildingType, { name: string; cost: number; wood: number; food: number; housing: number; happiness: number; desc: string; color: number }> = {
  house: { name: '茅舍', cost: 10, wood: 0, food: 0, housing: 4, happiness: 0, desc: '人口容量 +4，维护粮食 1/日', color: 0xc98963 },
  lumber: { name: '伐木场', cost: 20, wood: 5, food: 0, housing: 0, happiness: 0, desc: '每日木材 +5', color: 0x8a5c3b },
  farm: { name: '农田', cost: 15, wood: 0, food: 8, housing: 0, happiness: 1, desc: '每日粮食 +8，需靠近水源', color: 0xb9956e },
  warehouse: { name: '仓库', cost: 30, wood: 0, food: 0, housing: 0, happiness: 0, desc: '粮食与木材容量各 +50', color: 0x7f6b52 },
  workshop: { name: '小工坊', cost: 35, wood: 2, food: 0, housing: 0, happiness: 2, desc: '每日木材 +2，幸福度 +2（需 8 人）', color: 0x5e7173 }
};

type State = {
  day: number; wood: number; food: number; population: number; happiness: number;
  lowHappinessDays: number; buildings: Building[]; selected: BuildingType | null; demolish: boolean;
  ended: 'win' | 'lose' | null; nextId: number; logs: string[];
};

type SaveData = {
  day: number; wood: number; food: number; population: number; happiness: number;
  lowHappinessDays: number; nextId: number; logs: string[];
  buildings: Array<Pick<Building, 'id' | 'type' | 'x' | 'z'>>;
};

const state: State = {
  day: 1, wood: 100, food: 40, population: 4, happiness: 60, lowHappinessDays: 0,
  buildings: [], selected: null, demolish: false, ended: null, nextId: 1, logs: []
};

const gameEl = document.querySelector<HTMLDivElement>('#game')!;
const hudEl = document.querySelector<HTMLDivElement>('#hud')!;
const buildEl = document.querySelector<HTMLDivElement>('#build-panel')!;
const inspectorEl = document.querySelector<HTMLDivElement>('#inspector')!;
const logEl = document.querySelector<HTMLDivElement>('#message-log')!;

const scene = new THREE.Scene();
scene.background = new THREE.Color(0xb9d7d5);
scene.fog = new THREE.Fog(0xb9d7d5, 45, 90);
const renderer = new THREE.WebGLRenderer({ antialias: true });
renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
renderer.shadowMap.enabled = true;
gameEl.appendChild(renderer.domElement);

const camera = new THREE.OrthographicCamera(-22, 22, 16, -16, 0.1, 200);
camera.position.set(24, 28, 25);
camera.lookAt(0, 0, 0);
const target = new THREE.Vector3(0, 0, 0);
const raycaster = new THREE.Raycaster();
const pointer = new THREE.Vector2();
const groundHit = new THREE.Plane(new THREE.Vector3(0, 1, 0), 0);
const world = new THREE.Group();
scene.add(world);

scene.add(new THREE.HemisphereLight(0xe7f3ed, 0x566b58, 2.2));
const sun = new THREE.DirectionalLight(0xffe0ad, 2.5);
sun.position.set(-20, 35, 15); sun.castShadow = true; scene.add(sun);

const tileMeshes: THREE.Mesh[] = [];
const occupied = new Map<string, Building>();
let hover: THREE.Group | null = null;
let selectedBuilding: Building | null = null;

function capacities() {
  const warehouses = state.buildings.filter((building) => building.type === 'warehouse').length;
  return { wood: 100 + warehouses * 50, food: 100 + warehouses * 50 };
}

function tileKey(x: number, z: number) { return `${x},${z}`; }
function gridToWorld(x: number, z: number) { return new THREE.Vector3((x - HALF + .5) * TILE, 0, (z - HALF + .5) * TILE); }
function worldToGrid(p: THREE.Vector3) { return { x: Math.floor(p.x / TILE + HALF), z: Math.floor(p.z / TILE + HALF) }; }

function createTerrain() {
  const base = new THREE.Mesh(new THREE.BoxGeometry(GRID * TILE + 2, 0.6, GRID * TILE + 2), new THREE.MeshLambertMaterial({ color: 0x75906f }));
  base.position.y = -0.35; base.receiveShadow = true; world.add(base);
  const tileGeo = new THREE.BoxGeometry(TILE - .06, .12, TILE - .06);
  const riverMat = new THREE.MeshLambertMaterial({ color: 0x5d9da7, transparent: true, opacity: .88 });
  for (let z = 0; z < GRID; z++) {
    for (let x = 0; x < GRID; x++) {
      const river = x === 2 || x === 3;
      const mat = river ? riverMat : new THREE.MeshLambertMaterial({ color: (x + z) % 3 === 0 ? 0x8faf82 : 0x87a97a });
      const tile = new THREE.Mesh(tileGeo, mat); tile.position.copy(gridToWorld(x, z)); tile.position.y = river ? .03 : .08;
      tile.receiveShadow = true; tile.userData.grid = { x, z }; world.add(tile); tileMeshes.push(tile);
    }
  }
  const grid = new THREE.GridHelper(GRID * TILE, GRID, 0x6f8c75, 0x99ad91); grid.position.y = .16; world.add(grid);
  const roadMat = new THREE.MeshLambertMaterial({ color: 0xb9956e });
  for (let z = 4; z < 16; z++) {
    const road = new THREE.Mesh(new THREE.BoxGeometry(1.1, .06, 1.85), roadMat); road.position.copy(gridToWorld(10, z)); road.position.y = .18; world.add(road);
  }
  const bridge = new THREE.Mesh(new THREE.BoxGeometry(4.1, .22, 1.4), new THREE.MeshLambertMaterial({ color: 0x8a5c3b })); bridge.position.set(gridToWorld(2, 9).x + TILE / 2, .32, gridToWorld(2, 9).z); bridge.castShadow = true; world.add(bridge);
  const trunkGeo = new THREE.CylinderGeometry(.11, .15, 1.1, 6); const crownGeo = new THREE.ConeGeometry(.65, 1.5, 7);
  const trunkMat = new THREE.MeshLambertMaterial({ color: 0x674632 }); const crownMat = new THREE.MeshLambertMaterial({ color: 0x506f51 });
  for (let z = 1; z < GRID - 1; z += 2) for (let x = 16; x < GRID; x += 2) {
    const tree = new THREE.Group(); const trunk = new THREE.Mesh(trunkGeo, trunkMat); trunk.position.y = .75; const crown = new THREE.Mesh(crownGeo, crownMat); crown.position.y = 1.85; crown.castShadow = true; tree.add(trunk, crown); tree.position.copy(gridToWorld(x, z)); tree.position.x += (z % 3) * .13; world.add(tree);
  }
  // Low-poly hills at the edge frame the town without external assets.
  const hillMat = new THREE.MeshLambertMaterial({ color: 0x68816f });
  for (let i = 0; i < 12; i++) {
    const hill = new THREE.Mesh(new THREE.ConeGeometry(3 + (i % 3), 7 + (i % 2) * 3, 6), hillMat);
    hill.position.set(-25 + i * 4.5, 2.8, -22 + (i % 2) * 4); hill.scale.z = .75; world.add(hill);
  }
}

function makeBuildingMesh(type: BuildingType, ghost = false) {
  const d = defs[type]; const g = new THREE.Group();
  const material = new THREE.MeshLambertMaterial({ color: d.color, transparent: ghost, opacity: ghost ? .52 : 1 });
  const roofMat = new THREE.MeshLambertMaterial({ color: type === 'farm' ? 0xb5a55e : 0x536c73, transparent: ghost, opacity: ghost ? .5 : 1 });
  const base = new THREE.Mesh(new THREE.BoxGeometry(1.45, .35, 1.45), material); base.position.y = .25; base.castShadow = !ghost; base.receiveShadow = true; g.add(base);
  if (type === 'farm') {
    for (let i = -1; i <= 1; i++) { const row = new THREE.Mesh(new THREE.BoxGeometry(1.35, .08, .22), new THREE.MeshLambertMaterial({ color: 0x805e3d, transparent: ghost, opacity: ghost ? .5 : 1 })); row.position.set(0, .48, i * .38); g.add(row); }
    const scare = new THREE.Mesh(new THREE.CylinderGeometry(.04, .04, .8, 5), new THREE.MeshLambertMaterial({ color: 0x69442e })); scare.position.set(.35, .85, 0); g.add(scare);
  } else {
    const roof = new THREE.Mesh(new THREE.ConeGeometry(1.22, type === 'warehouse' ? .95 : .78, 4), roofMat); roof.position.y = 1.1; roof.rotation.y = Math.PI / 4; roof.castShadow = !ghost; g.add(roof);
    const door = new THREE.Mesh(new THREE.BoxGeometry(.3, .48, .04), new THREE.MeshLambertMaterial({ color: 0x47382e, transparent: ghost, opacity: ghost ? .45 : 1 })); door.position.set(0, .48, .74); g.add(door);
    if (type === 'lumber') { for (let i = -1; i <= 1; i++) { const log = new THREE.Mesh(new THREE.CylinderGeometry(.12, .12, 1.3, 7), new THREE.MeshLambertMaterial({ color: 0x6b4029 })); log.rotation.z = Math.PI / 2; log.position.set(i * .35, .55, -.78); g.add(log); } }
    if (type === 'workshop') { const chimney = new THREE.Mesh(new THREE.BoxGeometry(.2, .55, .2), new THREE.MeshLambertMaterial({ color: 0x754c3c })); chimney.position.set(.55, 1.25, -.3); g.add(chimney); }
  }
  g.userData.type = type;
  return g;
}

function addBuilding(type: BuildingType, x: number, z: number, free = false) {
  const key = tileKey(x, z); if (occupied.has(key)) return false;
  const b: Building = { id: state.nextId++, type, x, z, mesh: makeBuildingMesh(type) };
  b.mesh.position.copy(gridToWorld(x, z)); world.add(b.mesh); state.buildings.push(b); occupied.set(key, b);
  if (!free) state.wood -= defs[type].cost;
  return true;
}
function removeBuilding(b: Building) {
  world.remove(b.mesh); b.mesh.traverse((obj) => { const mesh = obj as THREE.Mesh; mesh.geometry?.dispose(); });
  occupied.delete(tileKey(b.x, b.z)); state.buildings = state.buildings.filter((entry) => entry !== b);
  state.wood = Math.min(capacities().wood, state.wood + Math.floor(defs[b.type].cost * .5));
  if (selectedBuilding === b) { selectedBuilding = null; inspectorEl.classList.remove('visible'); }
}

function canPlace(type: BuildingType, x: number, z: number): string | null {
  if (x < 0 || x >= GRID || z < 0 || z >= GRID) return '超出河谷边界';
  if (x === 2 || x === 3) return '河道上不能建造';
  if (occupied.has(tileKey(x, z))) return '这里已有建筑';
  if (state.wood < defs[type].cost) return `木材不足（需要 ${defs[type].cost}）`;
  if (type === 'farm' && Math.abs(x - 2) > 2) return '农田需要靠近河流';
  if (type === 'lumber' && x < 14) return '伐木场需要建在东侧林地附近';
  if (type === 'workshop' && state.population < 8) return '小工坊需要人口达到 8';
  return null;
}

function updateHover(x: number, z: number) {
  if (hover) { world.remove(hover); hover = null; }
  if (!state.selected || x < 0 || x >= GRID || z < 0 || z >= GRID) return;
  const invalid = canPlace(state.selected, x, z);
  hover = makeBuildingMesh(state.selected, true); hover.position.copy(gridToWorld(x, z));
  (hover.children[0] as THREE.Mesh).material = new THREE.MeshLambertMaterial({ color: invalid ? 0xb94a42 : 0xd6a74a, transparent: true, opacity: .34 });
  world.add(hover);
}

function log(message: string, kind: 'normal' | 'warn' | 'good' = 'normal') {
  state.logs.unshift(message); state.logs = state.logs.slice(0, 8);
  const toast = document.createElement('div'); toast.className = `toast ${kind === 'normal' ? '' : kind}`; toast.textContent = message; logEl.prepend(toast);
  window.setTimeout(() => toast.remove(), 5000);
}

function renderHud() {
  const capacity = state.buildings.reduce((n, b) => n + defs[b.type].housing, 0);
  const storage = capacities();
  const progress = `${Math.min(state.population, 20)}/20 人 · ${Math.min(state.food, 50)}/50 粮`;
  hudEl.innerHTML = `<div class="brand">东境 · 孤城新生</div><div class="stat"><span class="icon">☀</span><span>第</span><b>${state.day}</b><span>日</span></div><div class="stat"><span class="icon">🪵</span><b>${state.wood}</b><span>/${storage.wood}</span></div><div class="stat"><span class="icon">🌾</span><b>${state.food}</b><span>/${storage.food}</span></div><div class="stat"><span class="icon">👥</span><b>${state.population}</b><span>/${capacity}</span></div><div class="stat"><span class="icon">♡</span><b>${state.happiness}</b></div><div class="goal"><strong>河谷复兴</strong><br>${progress}</div>`;
  for (const btn of buildEl.querySelectorAll<HTMLButtonElement>('[data-build]')) { const t = btn.dataset.build as BuildingType; btn.classList.toggle('active', state.selected === t); btn.disabled = !!state.ended; }
}

function renderInspector() {
  if (!selectedBuilding) return;
  const d = defs[selectedBuilding.type]; inspectorEl.classList.add('visible'); inspectorEl.innerHTML = `<h3>${d.name}</h3><div>${d.desc}</div><div class="muted">位置：${selectedBuilding.x + 1}，${selectedBuilding.z + 1}</div><button id="inspect-demolish" class="action-btn demolish" style="margin-top:10px">拆除（返还 ${Math.floor(d.cost * .5)} 木材）</button>`;
  document.querySelector<HTMLButtonElement>('#inspect-demolish')?.addEventListener('click', () => { if (selectedBuilding) { removeBuilding(selectedBuilding); log(`已拆除${d.name}，返还木材`, 'good'); renderHud(); } });
}

function renderBuildPanel() {
  buildEl.innerHTML = Object.entries(defs).map(([type, d]) => `<button class="build-btn" data-build="${type}"><span class="name">${d.name}</span><span class="cost">🪵 ${d.cost} · ${d.desc.split('，')[0]}</span></button>`).join('') + '<button id="next-day" class="action-btn next">下一日 ▶</button><button id="save" class="action-btn">保存</button><button id="load" class="action-btn">读取</button><button id="reset" class="action-btn">重置</button><button id="cancel-build" class="action-btn">选择/查看</button>';
  buildEl.querySelectorAll<HTMLButtonElement>('[data-build]').forEach((button) => button.addEventListener('click', () => { state.selected = button.dataset.build as BuildingType; state.demolish = false; log(`请选择格子放置${defs[state.selected].name}`); renderHud(); }));
  document.querySelector<HTMLButtonElement>('#next-day')!.addEventListener('click', nextDay);
  document.querySelector<HTMLButtonElement>('#save')!.addEventListener('click', () => saveGame());
  document.querySelector<HTMLButtonElement>('#load')!.addEventListener('click', loadGame);
  document.querySelector<HTMLButtonElement>('#reset')!.addEventListener('click', resetGame);
  document.querySelector<HTMLButtonElement>('#cancel-build')!.addEventListener('click', () => { state.selected = null; state.demolish = false; if (hover) { world.remove(hover); hover = null; } renderHud(); });
}

function nextDay() {
  if (state.ended) return;
  let woodGain = 0, foodGain = 0;
  state.buildings.forEach((b) => { woodGain += defs[b.type].wood; foodGain += defs[b.type].food; });
  const upkeep = state.buildings.filter((b) => b.type === 'house' || b.type === 'workshop').length;
  const rations = Math.ceil(state.population * .25);
  const storage = capacities();
  state.wood = Math.min(storage.wood, state.wood + woodGain);
  state.food = Math.max(0, Math.min(storage.food, state.food + foodGain - upkeep - rations));
  const capacity = state.buildings.reduce((n, b) => n + defs[b.type].housing, 0);
  if (state.day % 2 === 0 && state.population < capacity && state.food >= state.population * 2 && state.happiness >= 55) { state.population += Math.min(2, capacity - state.population); state.happiness = Math.min(100, state.happiness + 3); log('新居民迁入河谷，人口增加', 'good'); }
  state.happiness = Math.max(0, Math.min(100, state.happiness + state.buildings.filter((b) => b.type === 'farm').length - (state.food <= 0 ? 12 : 0)));
  if (state.happiness < 20) state.lowHappinessDays++; else state.lowHappinessDays = 0;
  state.day++;
  const event = state.day % 4;
  if (event === 0) { state.food = Math.min(capacities().food, state.food + state.buildings.filter((b) => b.type === 'farm').length * 8); log('丰收：农田产出翻倍，本日额外获得粮食', 'good'); }
  else if (event === 1) { state.wood = Math.max(0, state.wood - state.buildings.filter((b) => b.type === 'lumber').length * 2); log('雨季：伐木场产出受影响', 'warn'); }
  else if (event === 2 && state.food >= 10) { state.food -= 10; state.wood = Math.min(capacities().wood, state.wood + 25); log('商旅抵达：支付 10 粮食换取 25 木材', 'good'); }
  else if (event === 3) { state.happiness = Math.max(0, state.happiness - 8); log('居民争执：幸福度 -8，可通过建设工坊改善', 'warn'); }
  if (state.population >= 20 && state.food >= 50) endGame('win');
  if (state.food <= 0 || state.lowHappinessDays >= 3) endGame('lose');
  saveGame(false);
  renderHud();
}

function saveGame(notify = true) {
  const data: SaveData = {
    day: state.day, wood: state.wood, food: state.food, population: state.population,
    happiness: state.happiness, lowHappinessDays: state.lowHappinessDays, nextId: state.nextId,
    logs: state.logs, buildings: state.buildings.map(({ id, type, x, z }) => ({ id, type, x, z }))
  };
  localStorage.setItem('the-east-save-v1', JSON.stringify(data));
  if (notify) log('进度已保存在当前浏览器', 'good');
}

function loadGame() {
  const raw = localStorage.getItem('the-east-save-v1');
  if (!raw) { log('没有找到可读取的存档', 'warn'); return; }
  try {
    const data = JSON.parse(raw) as SaveData;
    const cells = new Set<string>();
    const invalidBuilding = !Array.isArray(data.buildings) || data.buildings.some((building) => {
      const key = tileKey(building.x, building.z);
      const invalid = !(building.type in defs) || !Number.isInteger(building.x) || !Number.isInteger(building.z)
        || building.x < 0 || building.x >= GRID || building.z < 0 || building.z >= GRID
        || building.x === 2 || building.x === 3 || cells.has(key);
      cells.add(key);
      return invalid;
    });
    if (!Number.isFinite(data.day) || !Number.isFinite(data.wood) || !Number.isFinite(data.food)
      || !Number.isFinite(data.population) || !Number.isFinite(data.happiness) || invalidBuilding) {
      throw new Error('Invalid save data');
    }
    clearBuildings();
    Object.assign(state, { ...data, buildings: [], selected: null, demolish: false, ended: null });
    for (const saved of data.buildings) {
      addBuilding(saved.type, saved.x, saved.z, true);
      state.buildings[state.buildings.length - 1].id = saved.id;
    }
    state.nextId = data.nextId;
    selectedBuilding = null; inspectorEl.classList.remove('visible');
    log('存档已读取', 'good'); renderHud();
  } catch {
    log('存档内容损坏，未覆盖当前进度', 'warn');
  }
}

function endGame(kind: 'win' | 'lose') {
  state.ended = kind; const win = kind === 'win';
  const modal = document.createElement('div'); modal.className = 'modal-backdrop'; modal.innerHTML = `<div class="modal"><h2>${win ? '河谷复兴！' : '聚落陷入困境'}</h2><p>${win ? '你让新城拥有了稳定的粮食与居民，河谷重新焕发生机。' : '粮食耗尽或民心持续低落。调整布局后再试一次吧。'}</p><button class="action-btn next" id="modal-reset">重新开始</button></div>`; document.body.appendChild(modal);
  modal.querySelector<HTMLButtonElement>('#modal-reset')!.addEventListener('click', () => { modal.remove(); resetGame(); });
}

function clearBuildings() {
  for (const b of [...state.buildings]) { world.remove(b.mesh); b.mesh.traverse((obj) => (obj as THREE.Mesh).geometry?.dispose()); }
  occupied.clear();
}

function resetGame() {
  clearBuildings();
  state.day = 1; state.wood = 100; state.food = 40; state.population = 4; state.happiness = 60; state.lowHappinessDays = 0; state.buildings = []; state.selected = null; state.demolish = false; state.ended = null; state.nextId = 1; occupied.clear(); selectedBuilding = null; inspectorEl.classList.remove('visible');
  addBuilding('house', 9, 9, true); log('新的里正抵达河谷：先在河岸建农田，再去东侧林地建伐木场', 'good'); renderHud();
}

function pickGround(event: PointerEvent) {
  const rect = renderer.domElement.getBoundingClientRect(); pointer.x = ((event.clientX - rect.left) / rect.width) * 2 - 1; pointer.y = -((event.clientY - rect.top) / rect.height) * 2 + 1; raycaster.setFromCamera(pointer, camera);
  const point = new THREE.Vector3(); return raycaster.ray.intersectPlane(groundHit, point) ? point : null;
}

let drag: { x: number; y: number; button: number; moved: boolean } | null = null;
renderer.domElement.addEventListener('contextmenu', (event) => event.preventDefault());
renderer.domElement.addEventListener('pointerdown', (event) => { drag = { x: event.clientX, y: event.clientY, button: event.button, moved: false }; renderer.domElement.setPointerCapture(event.pointerId); });
renderer.domElement.addEventListener('pointermove', (event) => {
  const point = pickGround(event); if (point) { const g = worldToGrid(point); updateHover(g.x, g.z); }
  if (!drag) return; const dx = event.clientX - drag.x, dy = event.clientY - drag.y; if (Math.abs(dx) + Math.abs(dy) < 3) return; drag.moved = true;
  if (drag.button === 2) { camera.position.applyAxisAngle(new THREE.Vector3(0, 1, 0), -dx * .008); camera.position.y = Math.max(14, Math.min(50, camera.position.y + dy * .08)); camera.lookAt(target); }
  else { const right = new THREE.Vector3().setFromMatrixColumn(camera.matrix, 0); const forward = new THREE.Vector3().setFromMatrixColumn(camera.matrix, 0); forward.crossVectors(camera.up, right).normalize(); target.addScaledVector(right, -dx * .045); target.addScaledVector(forward, dy * .045); camera.position.addScaledVector(right, -dx * .045); camera.position.addScaledVector(forward, dy * .045); camera.lookAt(target); }
  drag.x = event.clientX; drag.y = event.clientY;
});
renderer.domElement.addEventListener('pointerup', (event) => {
  if (!drag || drag.moved || event.button !== 0) { drag = null; return; }
  const point = pickGround(event); if (!point) { drag = null; return; } const g = worldToGrid(point); const existing = occupied.get(tileKey(g.x, g.z));
  if (state.selected) { const reason = canPlace(state.selected, g.x, g.z); if (reason) log(reason, 'warn'); else { addBuilding(state.selected, g.x, g.z); log(`已建造${defs[state.selected].name}`, 'good'); renderHud(); } }
  else if (existing) { selectedBuilding = existing; renderInspector(); }
  else { selectedBuilding = null; inspectorEl.classList.remove('visible'); }
  drag = null;
});
renderer.domElement.addEventListener('wheel', (event) => { event.preventDefault(); const scale = event.deltaY > 0 ? 1.1 : .9; camera.zoom = Math.max(.55, Math.min(2.2, camera.zoom * scale)); camera.updateProjectionMatrix(); }, { passive: false });

window.addEventListener('resize', () => { const aspect = window.innerWidth / window.innerHeight; const h = 18; camera.left = -h * aspect; camera.right = h * aspect; camera.top = h; camera.bottom = -h; camera.updateProjectionMatrix(); renderer.setSize(window.innerWidth, window.innerHeight); });

createTerrain(); renderBuildPanel(); resetGame(); window.dispatchEvent(new Event('resize'));
window.addEventListener('beforeunload', () => saveGame(false));
function animate() { requestAnimationFrame(animate); renderer.render(scene, camera); }
animate();
