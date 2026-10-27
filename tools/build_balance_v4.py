"""Generate live balance and document tables from explicit design targets.
No player saves, network or external dependencies. --check verifies reproducibility.
"""
from pathlib import Path
import json, math, copy, sys

ROOT = Path(__file__).resolve().parents[1]
BASE = json.loads((ROOT/'tools/balance_v4_baseline.json').read_text(encoding='utf-8'))
S, C = copy.deepcopy(BASE['specs']), copy.deepcopy(BASE['catalog'])
ORDER = ['well','hemp_farm','house','farm','lumber','workshop','warehouse','market','fishpond','weaver','orchard','freight','clinic','pavilion','garden','academy','theater','granary','dock','trading_post','tea_farm','teahouse','claypit','kiln','bamboo','papermill']
C = {key:C[key] for key in ORDER}
# Independent design anchors, not claimed to be mathematically proven fun.
ANCHORS = dict(day_seconds=60, household_size=4, farmer_basic=0.5,
    artisan_multiplier=2, farmer_cloth=0.25, well_rate=10, farm_rate=8,
    raw_timber_per_worker=6, artisan_labor_weight=1.5,
    wood_per_coin=0.5, foundation_budget=10, budget_per_cell=4,
    budget_per_worker=4, budget_per_unlock=4, one_material_share=0.30,
    two_material_share=0.20, new_households_per_stage=2,
    expansion_road_allowance=8, expansion_growth_per_stage=0.5,
    reserve_timber_days=2, reserve_food_days=3, expedition_food_days=2,
    reserve_cash_days=4, reward_fraction=0.25,
    empty_necessity_happiness_cap=55)
def ceil2(n): return 2*math.ceil((n-1e-9)/2)

S['well']['rate'] = ANCHORS['well_rate']
S['farm']['rate'] = ANCHORS['farm_rate']
S['fishpond']['rate'] = int(S['farm']['rate']*1.5)
S['orchard']['rate'] = int(S['farm']['rate']*1.75)
S['lumber']['rate'] = S['lumber']['workers']*ANCHORS['raw_timber_per_worker']
S['hemp_farm']['rate'] = 2*S['weaver']['input_rate']
S['bamboo']['rate'] = 2*S['papermill']['input_rate']
S['claypit']['rate'] = 2*S['kiln']['input_rate']
S['tea_farm']['rate'] = 4*2
for kind, s in S.items():
    if 'service' in s:
        s['maintenance'] = math.ceil(s['service_capacity']/16)+math.floor(s['service_bonus']/4)-1
    elif kind in ('weaver','papermill','kiln'):
        s['maintenance'] = math.ceil(s['workers']*.75)

NEEDS = {'farmer':dict(water=ANCHORS['farmer_basic'],food=ANCHORS['farmer_basic'],cloth=ANCHORS['farmer_cloth'],pottery=0),
         'artisan':dict(water=ANCHORS['farmer_basic']*ANCHORS['artisan_multiplier'],food=ANCHORS['farmer_basic']*ANCHORS['artisan_multiplier'],cloth=ANCHORS['farmer_cloth']*ANCHORS['artisan_multiplier'],pottery=.125)}
# Labor replacement weights in timber-equivalent units; not market prices.
WEIGHTS = {'wood':1.0,'coins':ANCHORS['wood_per_coin']}
for kind in ('well','farm','hemp_farm','bamboo','claypit','tea_farm'):
    s=S[kind]; WEIGHTS[s['output']]=s['workers']*ANCHORS['raw_timber_per_worker']/s['rate']
for kind in ('weaver','papermill','kiln'):
    s=S[kind]
    WEIGHTS[s['output']] = (s['workers']*ANCHORS['raw_timber_per_worker']*ANCHORS['artisan_labor_weight']+s['input_rate']*WEIGHTS[s['input']]+s.get('fuel_rate',0)*WEIGHTS.get(s.get('fuel'),0))/s['rate']

cost_derivation = {}
for kind, c in C.items():
    materials=c.get('resource_costs',{})
    if not materials: continue # Six explicit starting-kit anchors remain fixed.
    area=math.prod(c['footprint']); workers=S[kind]['workers']; level=c['unlock_level']
    budget=ANCHORS['foundation_budget']+ANCHORS['budget_per_cell']*area+ANCHORS['budget_per_worker']*workers+ANCHORS['budget_per_unlock']*level
    coins=ceil2(2*area+2*level+(2*workers if S[kind]['worker_kind']=='artisan' else 0))
    share=ANCHORS['one_material_share'] if len(materials)==1 else ANCHORS['two_material_share']
    for good in materials:
        materials[good]=ceil2(budget*share/WEIGHTS[good])
    # Loom setup uses one full hemp harvest, an explicit industry-chain anchor.
    if kind=='weaver': materials['hemp']=S['hemp_farm']['rate']
    material_value=sum(n*WEIGHTS[g] for g,n in materials.items())
    timber=ceil2(budget-coins*WEIGHTS['coins']-material_value)
    assert timber>0, (kind,budget,material_value)
    c['cost']=timber; c['coin_cost']=coins
    actual=timber+coins*WEIGHTS['coins']+material_value
    assert budget <= actual < budget+2.00001
    cost_derivation[kind]=dict(budget=budget,material_value=material_value,actual=actual)

REQ=[{}]; COST=[dict(wood=0,food=0,coins=0)]; REWARD=[dict(wood=0,food=0,coins=0,happiness=0)]
for k in range(1,7):
    population=ANCHORS['household_size']*ANCHORS['new_households_per_stage']*k; artisans=0 if k==1 else population//4
    daily_need=(population-artisans)*NEEDS['farmer']['food']+artisans*NEEDS['artisan']['food']
    wood=ceil2((ANCHORS['new_households_per_stage']*C['house']['cost']+ANCHORS['expansion_road_allowance'])*(1+ANCHORS['expansion_growth_per_stage']*(k-1)))
    coins=ANCHORS['new_households_per_stage']*C['house']['coin_cost']+8*k
    food=math.ceil(ANCHORS['expedition_food_days']*daily_need)
    COST.append(dict(wood=wood,food=food,coins=coins))
    REQ.append(dict(wood=wood+ANCHORS['reserve_timber_days']*S['lumber']['rate'],food=food+math.ceil(ANCHORS['reserve_food_days']*daily_need),coins=coins+ANCHORS['reserve_cash_days']*(S['workshop']['rate']-S['workshop']['maintenance']),population=population,happiness=55+5*(k-1)))
    REWARD.append(dict(wood=0,food=math.floor(food*ANCHORS['reward_fraction']),coins=math.floor(coins*ANCHORS['reward_fraction']),happiness=0))
VICTORY=dict(population=48,wood=COST[6]['wood']+4*S['lumber']['rate'],food=REQ[6]['food'],coins=COST[6]['coins']+8*(S['workshop']['rate']-S['workshop']['maintenance']),happiness=80)
OUT=dict(version=4,anchors=ANCHORS,specs=S,catalog=C,needs=NEEDS,weights=WEIGHTS,
    construction_derivation=cost_derivation,requirements=REQ,expansion_costs=COST,
    rewards=REWARD,victory=VICTORY,cloth_income=1,granary_capacity=200,pottery_unlock=5,
    empty_necessity_happiness_cap=ANCHORS['empty_necessity_happiness_cap'])

def gd(v):
    if isinstance(v,bool): return 'true' if v else 'false'
    if isinstance(v,dict):
        return '{'+', '.join(json.dumps(k,ensure_ascii=False)+': '+('Vector2i(%d, %d)'%tuple(x) if k=='footprint' else gd(x)) for k,x in v.items())+'}'
    if isinstance(v,list): return '['+', '.join(gd(x) for x in v)+']'
    return json.dumps(v,ensure_ascii=False)

generated='extends RefCounted\n## Generated by tools/build_balance_v4.py; edit design anchors/formulas, not this file.\n'
for key,value in [('SPECS',S),('CATALOG',C),('NEEDS',NEEDS),('REGION_REQUIREMENTS',REQ),('REGION_UNLOCK_COSTS',COST),('REGION_UNLOCK_REWARDS',REWARD),('VICTORY',VICTORY),('CLOTH_INCOME',1),('GRANARY_CAPACITY',200),('POTTERY_UNLOCK',5),('EMPTY_NECESSITY_HAPPINESS_CAP',ANCHORS['empty_necessity_happiness_cap'])]:
    generated+='const '+key+' = '+gd(value)+'\n'

table=['# V4 公式计算结果（自动生成）','', '由 `tools/build_balance_v4.py` 生成。不要直接编辑参数表。','',
 '| 建筑 | 解锁 | 占地 | 工人 | 维护/日 | 产出/日 | 建造材料 |', '| --- | ---: | --- | --- | ---: | --- | --- |']
names={'wood':'木材','coins':'铜钱','water':'水','food':'粮食','hemp':'麻料','cloth':'衣物','bamboo':'竹材','clay':'黏土','paper':'纸张','pottery':'陶器','tea':'茶叶'}
for kind,c in C.items():
    s=S[kind]; costs={'wood':c['cost'],'coins':c['coin_cost'],**c.get('resource_costs',{})}
    production=names[s['output']]+str(s['rate']) if 'output' in s else '—'
    if 'input' in s: production=names[s['input']]+str(s['input_rate'])+('＋木材'+str(s['fuel_rate']) if 'fuel' in s else '')+' → '+production
    if 'service' in s: production='服务%d人，幸福+%d'%(s['service_capacity'],s['service_bonus'])
    if kind=='granary': production='粮食仓容+200'
    table.append('| %s | %d | %d×%d | %s%d | %d | %s | %s |'%(c['name'],c['unlock_level'],*c['footprint'],'匠' if s['worker_kind']=='artisan' else '普',s['workers'],s['maintenance'],production,'、'.join(names[g]+str(n) for g,n in costs.items())))
table+=['','## 开拓目标与结算','', '| 下一地区 | 人口 | 幸福 | 目标木/粮/钱 | 支出木/粮/钱 | 奖励粮/钱 |','| ---: | ---: | ---: | --- | --- | --- |']
for k in range(1,7):
    r,c,b=REQ[k],COST[k],REWARD[k]
    table.append('| %d | %d | %d | %d/%d/%d | %d/%d/%d | %d/%d |'%(k,r['population'],r['happiness'],r['wood'],r['food'],r['coins'],c['wood'],c['food'],c['coins'],b['food'],b['coins']))
table+=['','最终复兴：人口%(population)d，幸福%(happiness)d，木材%(wood)d，粮食%(food)d，铜钱%(coins)d。'%VICTORY,'','## 建造预算核算','', '| 建筑 | 预算木材当量 | 特殊材料当量 | 最终当量（含取整） |','| --- | ---: | ---: | ---: |']
for kind,d in cost_derivation.items(): table.append('| %s | %.3f | %.3f | %.3f |'%(C[kind]['name'],d['budget'],d['material_value'],d['actual']))
files={ROOT/'godot/economy/BalanceV4.gd':generated,ROOT/'docs/balance-v4-values.json':json.dumps(OUT,ensure_ascii=False,indent=2)+'\n',ROOT/'docs/BALANCE_V4_TABLES.md':'\n'.join(table)+'\n'}
for path,content in files.items():
    if '--check' in sys.argv:
        assert path.read_text(encoding='utf-8')==content, f'Generated file drift: {path}'
    else: path.write_text(content,encoding='utf-8')
print('BALANCE_V4_GENERATION_OK: 26 buildings, 20 material budgets, 6 expansion stages')
