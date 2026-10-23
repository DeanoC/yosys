#!/usr/bin/env python3
from pathlib import Path
import argparse,subprocess,os,json,hashlib
p=argparse.ArgumentParser();p.add_argument('candidate');p.add_argument('baseline');p.add_argument('matrix');p.add_argument('output');a=p.parse_args();R=Path(a.output).resolve();R.mkdir(exist_ok=False);matrix=Path(a.matrix).resolve();candidate=str(Path(a.candidate).resolve());baseline=str(Path(a.baseline).resolve());rows=[]
def execute(name,binary,source,flow,threads=None):
 d=R/name;d.mkdir();(d/'top.v').write_text(source);env=dict(os.environ)
 if threads:env['YOSYS_MAX_THREADS']=str(threads)
 cmd=[binary,'-Q','-T','-p','read_verilog -sv top.v; '+flow+'; check; write_json result.json']
 x=subprocess.run(cmd,cwd=d,env=env,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT);(d/'run.log').write_text(x.stdout);row={'name':name,'command':cmd,'threads':threads,'returncode':x.returncode};rows.append(row);assert x.returncode==0,(name,x.stdout[-1000:]);return d,row
try:
 for init in [0,1]:
  for mode in ['proc','intel']:
   case=matrix/('absent_i%d_%s'%(init,mode));flow='synth_intel_alm -nolutram -nodsp -top top' if mode=='intel' else 'hierarchy -top top; proc; opt_merge; opt_clean'
   d,row=execute('baseline_i%d_%s'%(init,mode),baseline,(case/'top.v').read_text(),flow)
   before=(d/'result.json').read_text();after=(case/'result.json').read_text()
   row['byte_identical']=before==after
   baseline_share=str(Path(baseline).parent)+'/../share/yosys/'
   candidate_share=str(Path(candidate).parent/'share')+'/'
   assert Path(baseline_share).resolve()==Path(candidate_share).resolve()
   assert before.replace(baseline_share,'<PINNED_SHARE>/')==after.replace(candidate_share,'<PINNED_SHARE>/'),row['name']
   row['identical_except_verified_share_prefix']=True;row['passed']=True
 for mark in [False,True]:
  source='module top(input clk, input [1099:0] d, output reg [1099:0] a,b);\ngenvar i;generate for(i=0;i<1100;i=i+1)begin:g\n'+('(* nomerge=1 *) ' if mark else '')+'always @(posedge clk) a[i]<=d[i];\nalways @(posedge clk)b[i]<=d[i];\nend endgenerate\nendmodule\n'
  designs=[]
  for threads in [1,4]:
   d,row=execute('workers%d_mark%d'%(threads,mark),candidate,source,'hierarchy -top top; proc; opt_merge; opt_clean',threads)
   m=json.loads((d/'result.json').read_text())['modules']['top'];ffs=[c for c in m['cells'].values() if c['type']=='$dff'];assert len(ffs)==(2200 if mark else 1100),(row['name'],len(ffs));assert all('keep' not in c['attributes'] and 'dont_touch' not in c['attributes'] for c in ffs)
   assert sum(int(c['attributes'].get('nomerge','0'),2)!=0 for c in ffs)==(1100 if mark else 0)
   # Compare the observable alias partition; representative names may differ.
   alias=[x==y for x,y in zip(m['ports']['a']['bits'],m['ports']['b']['bits'])];assert all(x==not_mark for x,not_mark in zip(alias,[not mark]*1100));designs.append(alias);row['ff_count']=len(ffs);row['passed']=True
  assert designs[0]==designs[1]
finally:
 (R/'receipt.json').write_text(json.dumps({'candidate_sha256':hashlib.sha256(Path(candidate).read_bytes()).hexdigest(),'baseline_sha256':hashlib.sha256(Path(baseline).read_bytes()).hexdigest(),'results':rows,'passed':len(rows)==8 and all(x.get('passed') for x in rows)},indent=2)+'\n')
print('PASS 4 baseline controls (verified share-path normalization only) and 4 worker cases')
