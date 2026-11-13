#!/usr/bin/env python3
"""Adversarial local audit. Only clones the known synthetic phase-6 UI store.
Never opens PrivateFinance. simctl writes require the task's simulator permission.
"""
from pathlib import Path
import hashlib,json,sqlite3,subprocess,sys,uuid,time,os
ROOT=Path(__file__).resolve().parent.parent
DEVICE=os.environ.get('NUMA_SIMULATOR_ID', '')
if not DEVICE:
 raise SystemExit('Define NUMA_SIMULATOR_ID con un simulador local de prueba.')
BUNDLE='local.personal.finanzas'
SOURCE='UITest-5F730FF8-0569-41B2-9CCF-D5609EB79F62'
OUT=ROOT/(sys.argv[2] if len(sys.argv) > 2 else 'evidence/phase7')
assert OUT.resolve().is_relative_to((ROOT/'evidence').resolve())
OUT.mkdir(parents=True,exist_ok=True)
def sim(*args,env=None,check=True):
 return subprocess.run(['xcrun','simctl',*args],capture_output=True,text=True,check=check,env=env)
def fingerprint(path):
 try:
  with sqlite3.connect('file:'+str(path)+'?mode=ro',uri=True) as c:
   rows=c.execute('SELECT ZKIND,hex(ZID),hex(ZPAYLOAD) FROM ZSTOREDENTITY ORDER BY Z_PK').fetchall()
  return {'rows':len(rows),'logicalSHA256':hashlib.sha256(json.dumps(rows).encode()).hexdigest()}
 except sqlite3.DatabaseError:
  return {'invalidSQLiteSHA256':hashlib.sha256(path.read_bytes()).hexdigest()}
if sys.argv[1]=='prepare':
 sim('terminate',DEVICE,BUNDLE,check=False)
 container=Path(sim('get_app_container',DEVICE,BUNDLE,'data').stdout.strip())
 source=container/'Library/Application Support'/SOURCE/'Finance.store'
 assert SOURCE.startswith('UITest-') and source.is_file()
 c=sqlite3.connect('file:'+str(source)+'?mode=ro',uri=True)
 assert c.execute("SELECT count(*) FROM ZSTOREDENTITY WHERE ZKIND='entry'").fetchone()[0]==10001
 cases=[]
 for name in ['valid','invalid-json','identity-mismatch','unknown-kind','missing-reference','invalid-header']:
  token=str(uuid.uuid4()).upper(); directory=source.parent.parent/('UITest-'+token)
  directory.mkdir(exist_ok=False); target=directory/'Finance.store'
  with sqlite3.connect(target) as dest: c.backup(dest)
  if name=='invalid-header': target.write_bytes(b'SYNTHETIC AUDIT INVALID SQLITE HEADER\n')
  elif name!='valid':
   with sqlite3.connect(target) as dest:
    pk,payload=dest.execute("SELECT Z_PK,ZPAYLOAD FROM ZSTOREDENTITY WHERE ZKIND='entry' LIMIT 1").fetchone()
    data=json.loads(payload)
    if name=='invalid-json': dest.execute('UPDATE ZSTOREDENTITY SET ZPAYLOAD=? WHERE Z_PK=?',(b'{not json',pk))
    elif name=='unknown-kind': dest.execute('UPDATE ZSTOREDENTITY SET ZKIND=? WHERE Z_PK=?',('future-audit-kind',pk))
    else:
     if name=='identity-mismatch': data['id']=str(uuid.uuid4())
     elif name=='missing-reference': data['accountID']=str(uuid.uuid4())
     dest.execute('UPDATE ZSTOREDENTITY SET ZPAYLOAD=? WHERE Z_PK=?',(json.dumps(data).encode(),pk))
  cases.append({'name':name,'token':token,'directory':str(directory),'before':fingerprint(target)})
 (OUT/'storage-cases.json').write_text(json.dumps(cases,indent=2)+'\n')
 print('Prepared six isolated synthetic stores; source unchanged.')
elif sys.argv[1]=='run':
 cases=json.loads((OUT/'storage-cases.json').read_text())
 for case in cases:
  assert Path(case['directory']).name=='UITest-'+case['token']
  sim('terminate',DEVICE,BUNDLE,check=False)
  env=dict(os.environ,SIMCTL_CHILD_FINANCE_TEST_STORE=case['token'])
  result=sim('launch',DEVICE,BUNDLE,'--ui-testing','-AppleLanguages','(es)','-AppleLocale','es_MX',env=env,check=False)
  case['launchExit']=result.returncode
  time.sleep(3)
  shot=OUT/(case['name']+'.png')
  sim('io',DEVICE,'screenshot',str(shot))
  sim('terminate',DEVICE,BUNDLE,check=False)
  case['after']=fingerprint(Path(case['directory'])/'Finance.store')
  case['recordsPreserved']=case['before']==case['after']
  case['screenshot']=shot.name
  case['performanceFileCreated']=(Path(case['directory'])/'performance.json').exists()
  print(case['name'], 'records preserved:',case['recordsPreserved'],'launch exit:',result.returncode,flush=True)
 (OUT/'storage-results.json').write_text(json.dumps(cases,indent=2)+'\n')
 assert all(c['recordsPreserved'] and c['launchExit']==0 and not c['performanceFileCreated'] for c in cases)
