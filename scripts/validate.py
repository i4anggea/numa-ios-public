#!/usr/bin/env python3
"""Local Numa quality gates. Never signs, uploads, installs on a phone or deletes data."""
from pathlib import Path
import argparse,datetime,fcntl,hashlib,json,plistlib,re,shutil,subprocess,sys,tempfile,time
ROOT=Path(__file__).resolve().parent.parent

def check_sources(output):
    checked=0
    for path in [ROOT/'README.md',*sorted((ROOT/'docs').rglob('*.md'))]:
        content=path.read_text()
        if content.count('```')%2: raise RuntimeError('Bloque Markdown sin cerrar: '+str(path.relative_to(ROOT)))
        for target in re.findall(r'\[[^\]]*\]\(([^)]+)\)',content):
            if target.startswith(('http:','https:','mailto:','#','codex:')): continue
            target=target.strip('<>').split('#')[0]
            if not target: continue
            if not (path.parent/target).exists(): raise RuntimeError('Enlace inexistente en '+str(path.relative_to(ROOT))+': '+target)
            checked+=1
    # Generate only in a scratch tree; validation never rewrites developer config.
    scratch=output/'generated-check'; (scratch/'scripts').mkdir(parents=True)
    shutil.copy2(ROOT/'scripts/generate_project.py',scratch/'scripts/generate_project.py')
    for base in ['Sources','Support']:
        for path in (ROOT/base).rglob('*.swift'):
            target=scratch/path.relative_to(ROOT);target.parent.mkdir(parents=True,exist_ok=True);target.touch()
    (scratch/'Config').mkdir(exist_ok=True)
    for name in ['AppIdentity.json','ProjectSettings.json']:
        shutil.copy2(ROOT/'Config'/name,scratch/'Config'/name)
    config=ROOT/'Config/Signing.local.json'
    if config.exists():
        (scratch/'Config').mkdir(exist_ok=True);shutil.copy2(config,scratch/'Config/Signing.local.json')
    subprocess.run([sys.executable,str(scratch/'scripts/generate_project.py')],check=True,capture_output=True)
    for rel in ['Finanzas.xcodeproj/project.pbxproj','Finanzas.xcodeproj/xcshareddata/xcschemes/Finanzas.xcscheme','Config/Info.plist']:
        if (ROOT/rel).read_bytes()!=(scratch/rel).read_bytes(): raise RuntimeError('Proyecto desactualizado: ejecuta python3 scripts/generate_project.py')
    manifest=plistlib.loads((ROOT/'Config/PrivacyInfo.xcprivacy').read_bytes())
    if manifest.get('NSPrivacyTracking') is not False: raise RuntimeError('Revisar política de privacidad')
    icon=ROOT/'Assets/Numa.xcassets/AppIcon.appiconset/Numa.png'
    png=icon.read_bytes()
    if png[:8]!=b'\x89PNG\r\n\x1a\n' or int.from_bytes(png[16:20],'big')!=1024 or int.from_bytes(png[20:24],'big')!=1024:
        raise RuntimeError('El icono debe ser un PNG de 1024 × 1024.')
    if png[25] not in (0,2): raise RuntimeError('El icono debe ser opaco, sin canal alfa.')
    return {'localMarkdownLinks':checked,'generator':'PASS','privacyManifest':'PASS','appIcon':'PASS'}

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('mode',choices=['quick','full'])
    parser.add_argument('--simulator-id',help='UUID de un simulador iPhone disponible con iOS 27 o posterior')
    parser.add_argument('--output',type=Path,help='Directorio nuevo o vacío; por defecto se crea uno en /private/tmp')
    args=parser.parse_args()
    lock=open('/private/tmp/numa-local-validation.lock','a')
    try: fcntl.flock(lock,fcntl.LOCK_EX|fcntl.LOCK_NB)
    except BlockingIOError: parser.error('Ya hay otra validación local de Numa en ejecución.')
    output=args.output.resolve() if args.output else Path(tempfile.mkdtemp(prefix='numa-'+args.mode+'-',dir='/private/tmp'))
    if output.exists() and any(output.iterdir()): parser.error('El directorio de salida debe estar vacío; no se sobrescriben evidencias.')
    output.mkdir(parents=True,exist_ok=True)
    summary={'mode':args.mode,'startedUTC':datetime.datetime.now(datetime.timezone.utc).isoformat(),'status':'RUNNING','steps':[],
             'output':str(output),'signed':False,'installedOnPhone':False,'uploaded':False,
             'physicalVerification':'PENDING: docs/PRUEBAS_IPHONE.md'}
    def save(): (output/'summary.json').write_text(json.dumps(summary,indent=2,ensure_ascii=False)+'\n')
    def run(name,command):
        print(name+'…',flush=True); start=time.monotonic()
        with (output/(name+'.log')).open('w') as log:
            result=subprocess.run(command,cwd=ROOT,stdout=log,stderr=subprocess.STDOUT)
        summary['steps'].append({'name':name,'command':command,'exitCode':result.returncode,'seconds':round(time.monotonic()-start,3),'status':'PASS' if result.returncode==0 else 'FAIL'})
        save()
        if result.returncode: raise RuntimeError(name+' falló; revisar '+str(output/(name+'.log')))
    try:
        save()
        run('xcode-version',['xcodebuild','-version'])
        run('swift-version',['swift','--version'])
        summary['sourceChecks']=check_sources(output);save()
        run('configuration',['plutil','-lint','Config/Info.plist','Config/PrivacyInfo.xcprivacy','Finanzas.xcodeproj/project.pbxproj'])
        run('core-tests',['swift','test','--scratch-path',str(output/'swift-build')])
        core=(output/'core-tests.log').read_text()
        if not re.search(r'Executed [1-9]\d* tests, with 0 failures',core): raise RuntimeError('No se confirmó ejecución de pruebas de dominio.')
        if args.mode=='full':
            devices=json.loads(subprocess.check_output(['xcrun','simctl','list','devices','available','-j'],text=True))['devices']
            choices=[d for runtime,ds in devices.items() if re.search(r'iOS-(?:2[7-9]|[3-9]\d)-',runtime) for d in ds if d.get('isAvailable') and d['name'].startswith('iPhone')]
            if args.simulator_id: choices=[d for d in choices if d['udid']==args.simulator_id]
            if not choices: raise RuntimeError('No hay simulador iPhone iOS 27+ disponible para el destino elegido.')
            device=sorted(choices,key=lambda d:d.get('state')!='Booted')[0];summary['simulator']=device['udid'];save()
            run('simulator-tests',['xcodebuild','-project','Finanzas.xcodeproj','-scheme','Finanzas','-configuration','Debug','-destination','platform=iOS Simulator,id='+device['udid'],'-derivedDataPath',str(output/'simulator-build'),'-resultBundlePath',str(output/'tests.xcresult'),'-parallel-testing-enabled','NO','-collect-test-diagnostics','never','test'])
            tests=(output/'simulator-tests.log').read_text()
            for suite in ['StorageTests','FinanceUITests']:
                if not re.search(r"Test Suite '"+suite+r"(?:\.xctest)?' passed",tests): raise RuntimeError('No se confirmó suite aprobada: '+suite)
            archive=output/'Numa-unsigned.xcarchive'
            run('unsigned-archive',['xcodebuild','-project','Finanzas.xcodeproj','-scheme','Finanzas','-configuration','Release','-sdk','iphoneos','-destination','generic/platform=iOS','-derivedDataPath',str(output/'device-build'),'-archivePath',str(archive),'CODE_SIGNING_ALLOWED=NO','archive'])
            app=archive/'Products/Applications/Finanzas.app'
            if (app/'PrivacyInfo.xcprivacy').read_bytes()!=(ROOT/'Config/PrivacyInfo.xcprivacy').read_bytes(): raise RuntimeError('Manifiesto del archive distinto del fuente.')
            info=plistlib.loads((app/'Info.plist').read_bytes())
            if info.get('CFBundleDisplayName')!='Numa' or info.get('CFBundleIdentifier')!=json.loads((ROOT/'Config/AppIdentity.json').read_text())['bundleIdentifier']: raise RuntimeError('Identidad inesperada del archive.')
            binary=(app/'Finanzas').read_bytes()
            for marker in [b'FINANCE_TEST_STORE',b'FINANCE_TEST_SCENARIO',b'FINANCE_PERFORMANCE',b'performance.json',b'Movimiento de prueba',b'FaultRepository']:
                if marker in binary: raise RuntimeError('Marcador de pruebas presente en Release.')
            summary['archiveChecks']={'manifest':'PASS','identity':'PASS','debugMarkersAbsent':'PASS','binarySHA256':hashlib.sha256(binary).hexdigest()}
        summary['status']='PASS'
    except (Exception,KeyboardInterrupt) as error:
        summary['status']='FAIL';summary['failure']=str(error);save();print(str(error),file=sys.stderr);return 1
    finally:
        summary['finishedUTC']=datetime.datetime.now(datetime.timezone.utc).isoformat();save()
    print('PASS — '+str(output/'summary.json'),flush=True);return 0
if __name__=='__main__':sys.exit(main())
