"""Original design arithmetic only; never imports game or reads player saves."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TARGET = dict(wood=160, food=110, coins=85)
INITIAL = dict(wood=80.0, food=40.0, coins=60.0, hemp=0.0, cloth=0.0, tools=0.0)

def run_route(name, farmers, artisans, production, inputs, household, exports, imports, upkeep, jobs, external_limit=12):
    pop = farmers + artisans
    tax = farmers * 0.5 + artisans * 0.8
    retail = household.get('tools', 0) + household.get('cloth', 0) * 1.5
    sell_price = dict(food=0.5, wood=0.75, tools=2.0)
    buy_price = dict(cloth=4.0)
    trade_units = sum(exports.values()) + sum(imports.values())
    freight = trade_units * 0.125
    cash = tax + retail + sum(v * sell_price[k] for k, v in exports.items()) - sum(v * buy_price[k] for k, v in imports.items()) - freight - upkeep
    flows = {k: production.get(k, 0) + imports.get(k, 0) - inputs.get(k, 0) - household.get(k, 0) - exports.get(k, 0) for k in INITIAL if k != 'coins'}
    assert all(v >= 0 for v in flows.values()), flows
    load = sum(production.values()) + sum(inputs.values()) + sum(household.values()) + trade_units
    assert jobs <= 12 and trade_units <= external_limit and load <= 96
    stock = INITIAL.copy()
    reached = None
    # Minute-end continuous-flow abstraction, not a discrete parcel logistics simulator.
    for minute in range(1, 31):
        for k, v in flows.items():
            stock[k] += v
        stock['coins'] += cash
        assert stock['coins'] > 0 and all(v >= 0 for v in stock.values())
        assert all(stock[k] <= 500 for k in stock if k != 'coins')
        if reached is None and all(stock[k] >= target for k, target in TARGET.items()):
            reached = minute
    assert reached is not None
    return dict(name=name, population=pop, workers=jobs, available_workers=12, happiness_assumption=72 if household.get('cloth') else 60, cash_per_minute=round(cash, 4), resource_net_per_minute=flows, tax=tax, retail_income=retail, upkeep=upkeep, external_trade_capacity=external_limit, trade_units_per_minute=trade_units, freight=freight, warehouse_work_per_minute=load, resource_threshold_minute_at_fixed_population_and_assumed_happiness=reached, after_30_minutes={k: round(v, 4) for k,v in stock.items()})

routes = [
    run_route('本地自给', 12, 4, dict(food=16, hemp=8, wood=12, tools=4, cloth=4), dict(wood=4, hemp=4), dict(food=8, tools=2, cloth=2.5), {}, {}, 8, 12),
    run_route('木器外销与布衣进口', 12, 4, dict(food=16, wood=12, tools=8), dict(wood=8), dict(food=8, tools=2, cloth=2.5), dict(tools=6), dict(cloth=2.5), 7, 10),
    run_route('低阶粮木经营', 16, 0, dict(food=16, wood=12), {}, dict(food=8), dict(food=3, wood=1), {}, 3, 5, external_limit=4),
]
# Opening: three workers, two in grain and one in lumber; no market required.
opening = dict(population=4, workers=3, start_after_house_farm_lumber=dict(wood=48, food=40, coins=44), net_food=14, net_wood=6, net_coins=0, base_shed_load=24, base_shed_capacity=32)
assert opening['base_shed_load'] <= opening['base_shed_capacity']

def startup():
    from math import ceil
    stock = dict(wood=48.0, food=40.0, coins=44.0)
    population, capacity, warehouse = 4, 4, False
    rows = []
    # First house/farm/lumber already deducted from actual proposed opening 100/40/60.
    for minute in range(1, 13):
        actions = []
        if minute % 2 == 0 and population + 2 <= capacity and stock['food'] >= population + 2:
            population += 2
            actions.append('迁入2人')
        if minute in (1, 4, 6):
            stock['wood'] -= 12
            stock['coins'] -= 4
            capacity += 4
            actions.append('建民居，木-12钱-4')
        if minute == 2:
            stock['wood'] -= 30
            stock['coins'] -= 10
            warehouse = True
            actions.append('建仓库，木-30钱-10')
        workers = ceil(population * 0.7)
        lumber_workers = min(2, workers - 2 - int(warehouse))
        produced_wood = lumber_workers * 6
        load = 16 + produced_wood + population * 0.5
        assert load <= (96 if warehouse else 32)
        stock['food'] += 16 - population * 0.5
        stock['wood'] += produced_wood
        stock['coins'] += population * 0.5 - 2 - int(warehouse)
        assert stock['coins'] > 0 and stock['food'] >= population
        assert stock['food'] <= (500 if warehouse else 200)
        assert stock['wood'] <= (500 if warehouse else 200)
        rows.append(dict(minute=minute, population=population, capacity=capacity, workers=workers, assigned=2+lumber_workers+int(warehouse), warehouse_load=load, actions=actions, **stock))
    assert population == 16
    return rows

def crop_intervention(recover):
    # Sixteen farmers, one grain farm and one lumber site, staffed market warehouse.
    # At minute 1 grain switches to hemp; reserve starts at four minutes of food.
    stock = dict(food=32.0, coins=60.0, hemp=0.0)
    rows = []
    for minute in range(1, 5):
        grain = recover == 'restore_grain' and minute >= 2
        buy = 8 if recover == 'import_grain' and minute >= 2 else 0
        stock['food'] += (16 if grain else 0) + buy - 8
        stock['hemp'] += 0 if grain else 8
        # Food import 1.5/unit; basal 8 minus upkeep farm/lumber/market/warehouse=4.
        stock['coins'] += 4 - buy * (1.5 + 0.125)
        rows.append(dict(minute=minute, action='改回粮田' if grain else ('进口粮8' if buy else '改麻未处理'), **stock))
    if recover == 'restore_grain':
        assert stock['food'] > 32 and stock['coins'] > 60
    if recover == 'import_grain':
        assert stock['food'] > 0 and stock['coins'] > 0
    return rows
# A 50% trading capacity interruption prioritizes cloth imports (2.5), leaving 3.5 exports.
disrupted_export_cash = 9.2 + 5.75 + 3.5 * 2 - 2.5 * 4 - 6 * 0.125 - 7
assert disrupted_export_cash > 0
result = dict(scope='30-minute fixed-population flow comparison, 12-minute scripted opening and 4-minute crop intervention; no stochastic events or parcel/path scheduling', initial_stock=INITIAL, target=TARGET, assumptions=dict(max_inventory_per_good=500, warehouse_work=96, external_trade=12, road_distance_factor=1), routes=routes, opening=opening, startup=startup(), crop_interventions={k: crop_intervention(k) for k in ('none', 'restore_grain', 'import_grain')}, trade_half_capacity_cash_per_minute=round(disrupted_export_cash,4))
out = ROOT / 'docs' / 'economy_prototype_results.json'
out.write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding='utf-8')
print(json.dumps(result, ensure_ascii=False, indent=2))
