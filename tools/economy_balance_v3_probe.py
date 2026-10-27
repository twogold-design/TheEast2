"""V3 design arithmetic. Does not load Godot or player saves, and grants nothing.
Full-build steady states and conditional reserve runways are NOT paid playthroughs.
"""
from pathlib import Path
import json, math, copy
ROOT = Path(__file__).resolve().parents[1]
FOLDER = ROOT / 'qa' / 'economy-balance-v3'
P = json.loads((FOLDER / 'proposal-input.json').read_text(encoding='utf-8'))
GOODS = ['water','food','wood','hemp','cloth','tea','clay','pottery','bamboo','paper']

def clean(x):
    if isinstance(x,float): return round(x,6)
    if isinstance(x,dict): return {k:clean(v) for k,v in x.items()}
    if isinstance(x,list): return [clean(v) for v in x]
    return x

def account(plan, cloth_income=None, artisan_tax=None, allocate=False, blocked=()):
    counts=plan['buildings']; total=plan['population']; farmer=plan['farmer']; artisan=plan['artisan']
    assert farmer+artisan==total
    need=dict.fromkeys(GOODS,0.0)
    for tier,people in [('farmer',farmer),('artisan',artisan)]:
        for good,rate in P['needs'][tier].items():
            if good=='cloth' and not plan['clothing']: continue
            if good=='pottery' and not plan['pottery']: continue
            need[good]+=people*rate
    labor={'normal':0,'artisan':0}; free={'normal':farmer,'artisan':artisan}; operated={}; cuts={}
    gross=dict.fromkeys(GOODS,0.0); inputs=dict.fromkeys(GOODS,0.0)
    upkeep=0; workshop=0; areas=math.ceil(total/4); capital={'wood':math.ceil(total/4)*12+artisan/4*P['upgrade']['wood_cost'],'coins':math.ceil(total/4)*4+artisan/4*P['upgrade']['coin_cost']}
    for kind in P['priority']:
        count=counts.get(kind,0)
        if not count: continue
        b=P['buildings'][kind]
        staff=1.0
        for key in labor:
            jobs=b[key+'_workers']*count
            labor[key]+=jobs
            if allocate and jobs:
                staff=min(staff,max(0,min(1,free[key]/jobs)))
                free[key]-=min(free[key],jobs)
        if kind in blocked: staff=0
        operated[kind]=count*staff
        if staff<1: cuts[kind]=staff
        upkeep+=count*b['maintenance']; areas+=count*b['area']
        capital['wood']+=count*b['wood_cost']; capital['coins']+=count*b['coin_cost']
        for good,rate in b['outputs'].items():
            if good=='coins': workshop+=rate*count*staff
            else: gross[good]+=rate*count*staff
        for good,rate in b['inputs'].items(): inputs[good]+=rate*count*staff
    services={}; service_income=0
    for service in ['market','clinic','garden','culture','teahouse','academy']:
        cap=sum(operated.get(kind,0)*b['service_capacity'] for kind,b in P['buildings'].items() if b['service']==service)
        served=min(total,cap)
        services[service]={'seats':cap,'served_upper_bound':served,'coverage_upper_bound':served/total}
        if service in P['service_consumption']:
            item=P['service_consumption'][service]
            slots=P['buildings'][service]['service_capacity']
            inputs[item['good']]+=served/slots*item['daily_amount']
            service_income+=served/slots*item['daily_income']
    net={good:gross[good]-inputs[good]-need[good] for good in GOODS}
    tax=farmer*P['tax']['farmer']+artisan*(P['tax']['artisan'] if artisan_tax is None else artisan_tax)
    cloth_cash=need['cloth']*(P['consumption_income']['cloth'] if cloth_income is None else cloth_income)
    pottery_cash=need['pottery']*P['consumption_income']['pottery']
    cash=tax+cloth_cash+pottery_cash+workshop+service_income-upkeep
    normal_spare=farmer-labor['normal']; artisan_spare=artisan-labor['artisan']
    return clean(dict(name=plan['name'],population=total,farmer=farmer,artisan=artisan,buildings=counts,need_daily=need,gross_daily=gross,inputs_daily=inputs,net_daily=net,normal_jobs=labor['normal'],artisan_jobs=labor['artisan'],normal_spare=normal_spare,artisan_spare=artisan_spare,maintenance=upkeep,income={'tax':tax,'cloth':cloth_cash,'pottery':pottery_cash,'workshop':workshop,'tea_service':service_income},net_coins_full_supply=cash,construction_capital=capital,building_cells_excluding_roads=areas,service_coverage_upper_bounds=services,production_ratios=cuts,feasible_full_output=normal_spare>=0 and artisan_spare>=0 and min(net.values())>=-1e-8 and cash>0,cash_assumption='All demanded goods actually consumed; service figures assume reachable distinct residents. If shortages occur this full-supply cash is not an attainable guarantee.'))

def variant(index,name,farmer=None,artisan=None,extra=None):
    plan=copy.deepcopy(P['plans'][index]);plan['name']=name
    if farmer is not None: plan['farmer']=farmer
    if artisan is not None: plan['artisan']=artisan
    plan['population']=plan['farmer']+plan['artisan']
    for key,n in (extra or {}).items():plan['buildings'][key]=plan['buildings'].get(key,0)+n
    return plan

base=[account(p) for p in P['plans']]
stress={}
stress['24_population_second_lumber']=account(variant(1,'24人主动双伐木',extra={'lumber':1}))
stress['upgrade_eight_farmers_without_new_basics']=account(variant(2,'40人口盲升8匠',farmer=20,artisan=20),allocate=True)
stress['upgrade_sixteen_farmers_without_new_basics']=account(variant(2,'40人口盲升16匠',farmer=12,artisan=28),allocate=True)
stress['add_eight_farmers_without_new_industry']=account(variant(1,'24→32人口不扩产业',farmer=24,artisan=8),allocate=True)
stress['overspend_on_services']=account(variant(2,'40人再造4戏台4医馆2书院',extra={'theater':4,'clinic':4,'academy':2}),allocate=True)
stress['hemp_disconnected_first_stage']=account(P['plans'][2],allocate=True,blocked=('hemp_farm',))
stress['hemp_disconnected_after_stock_empty']=account(P['plans'][2],allocate=True,blocked=('hemp_farm','weaver',))
# This shortage profile explicitly enables clothing instead of hiding locked needs.
v=variant(0,'12人8农4匠完整衣链',farmer=8,artisan=4,extra={'hemp_farm':1,'weaver':1});v['clothing']=True
stress['12_population_mixed_chain']=account(v,allocate=True)
wood_options=[]
for extra in range(0,5):
    q=variant(2,f'40人额外{extra}小工坊',extra={'workshop':extra})
    r=account(q)
    wood_options.append({'extra_workshops':extra,'normal_jobs':r['normal_jobs'],'normal_spare':r['normal_spare'],'net_wood_if_fully_staffed':r['net_daily']['wood'],'net_coins_if_fully_staffed_and_fed':r['net_coins_full_supply'],'new_capital_wood':38*extra,'new_capital_coins':16*extra,'feasible_full_output':r['feasible_full_output'],'conditional_cash_payback_days':16/10 if extra else None,'conditional_wood_recovery_days':None if extra==0 else (38*extra/r['net_daily']['wood'] if r['net_daily']['wood']>0 else None),'actual_fixed_priority_allocation':account(q,allocate=True)})
# Calculate shortfall runways from actual existing reserves supplied by the player,
# not from invented automatic aid. Values are explicit conditional examples.
runways={
'cloth_hemp_break_40':{'if_existing_hemp':16,'hemp_consumption_per_day':16,'days_until_weavers_stop':1,'if_existing_clothes':26,'clothes_consumption_per_day':13,'continuous_rate_days_until_clothes_empty':1+(26+3)/13,'note':'Conditional starting reserves:16 hemp and26 clothes. First day produces net3 additional clothes; after hemp is gone,29 clothes sustain13 per day. Actual journey and tick order not simulated.'},
'growth_24_to_32':{'net_cloth_per_day':stress['add_eight_farmers_without_new_industry']['net_daily']['cloth'],'if_existing_clothes':20,'days_to_empty':20/max(.00001,-stress['add_eight_farmers_without_new_industry']['net_daily']['cloth'])},
}
sensitivity=[]
for price in [2,1,.5]:
    for tax in [1,.5]:
        sensitivity.append({'cloth_income':price,'artisan_tax':tax,'profits_by_population':{str(p['population']):account(p,cloth_income=price,artisan_tax=tax)['net_coins_full_supply'] for p in P['plans']}})
result={'kind':'Independent design arithmetic, not implementation or paid playthrough','proposal':P,'baseline':base,'pressure':stress,'wood_cash_conflict':wood_options,'conditional_runways':runways,'income_sensitivity':sensitivity,'limits':['No goods, workers, construction or money are granted in a live game. All static layouts require the full stated capital beforehand.','No actual terrain/roads, logistics latency, population migration/departure, happiness transition or source diversity is simulated.','All output is ideal full-capacity where feasible. Scenarios with shortages identify deficits; full-supply revenues are explicitly upper bounds.','Maintenance is charged for every built facility even when jobs or raw materials are missing.','Per-person clothes/pottery income applies once per actual final demand; tea services are capped by distinct residents, never duplicated across buildings.']}
FOLDER.mkdir(parents=True,exist_ok=True)
(FOLDER/'validation-results.json').write_text(json.dumps(clean(result),ensure_ascii=False,indent=2),encoding='utf-8')
for r in base:print(r['name'], 'jobs',r['normal_jobs'],r['artisan_jobs'],'net',r['net_daily'],'coins',r['net_coins_full_supply'],'upkeep',r['maintenance'],'capital',r['construction_capital'],'area',r['building_cells_excluding_roads'])
for name,r in stress.items():print(name,'ratios',r['production_ratios'],'net',r['net_daily'],'coins upper',r['net_coins_full_supply'])
