#!/usr/bin/env python3
"""Observable one-bit FF identity and actual Intel ALM mapping, no placement/timing."""
from pathlib import Path
import argparse,json,subprocess,hashlib,os
p=argparse.ArgumentParser();p.add_argument('yosys');p.add_argument('output');p.add_argument('--share',required=True);a=p.parse_args()
R=Path(a.output).resolve();R.mkdir(exist_ok=False);binary=str(Path(a.yosys).resolve());env=dict(os.environ,YOSYS_DATDIR=str(Path(a.share).resolve()))
results=[]
def run(name,marks,init,mapped=False,unused=False):
 d=R/name;d.mkdir();attrs=['' if x is None else '(* nomerge = %d *) '%x for x in marks]
 ports='output reg q0 = 1\'b%d'%init+('' if unused else ', output reg q1 = 1\'b%d'%init)
 text='module top(input clk, d, '+ports+');\n'+('reg q1 = 1\'b%d;\n'%init if unused else '')
 for i in range(2):text+=attrs[i]+'always @(posedge clk) q%d <= d;\n'%i
 text+='endmodule\n';(d/'top.v').write_text(text)
 flow='synth_intel_alm -nolutram -nodsp -top top' if mapped else 'hierarchy -top top; proc; opt_merge; opt_clean'
 command=[binary,'-Q','-T','-p','read_verilog top.v; '+flow+'; check; write_json result.json']
 proc=subprocess.run(command,cwd=d,env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True);(d/'run.log').write_text(proc.stdout)
 result={'case':name,'command':command,'returncode':proc.returncode,'mapped':mapped,'initial':init,'marks':marks,'unused':unused};results.append(result)
 if proc.returncode:raise AssertionError(name+': Yosys failed')
 m=json.loads((d/'result.json').read_text())['modules']['top'];cells=m['cells'];ffs=[c for c in cells.values() if c['type']==('MISTRAL_FF' if mapped else '$dff')]
 expected=1 if unused or not any(marks) else 2
 assert len(ffs)==expected,(name,len(ffs),expected)
 assert all('keep' not in c['attributes'] and 'dont_touch' not in c['attributes'] for c in ffs),name
 marked=sum(int(c['attributes'].get('nomerge','0'),2)!=0 for c in ffs)
 assert marked==(int(bool(marks[0])) if unused else sum(bool(x) for x in marks)),(name,marked)
 if not mapped:
  for c in ffs:assert c['connections']['CLK']==m['ports']['clk']['bits'] and c['connections']['D']==m['ports']['d']['bits']
  qbits=[c['connections']['Q'][0] for c in ffs]
  for q in qbits:
   attrs=[n['attributes'].get('init') for n in m['netnames'].values() if n['bits']==[q] and 'init' in n['attributes']]
   assert attrs and all(int(x,2)==init for x in attrs),(name,q,attrs)
 else:
  # Native power-up-zero mapping represents init1 through inversion. The
  # actual polarity and DATAIN/output correspondence are checked below.
  drivers={bit:(c,port) for c in cells.values() for port,direction in c.get('port_directions',{}).items() if direction=='output' for bit in c['connections'][port] if isinstance(bit,int)}
  def through_not(bit):
   parity=0;seen=set()
   while bit in drivers and drivers[bit][0]['type'] in ('MISTRAL_NOT','MISTRAL_IB','MISTRAL_OB','MISTRAL_CLKBUF'):
    assert bit not in seen;seen.add(bit);c=drivers[bit][0];kind=c['type']
    parity^=int(kind=='MISTRAL_NOT');port={'MISTRAL_NOT':'A','MISTRAL_IB':'PAD','MISTRAL_OB':'I','MISTRAL_CLKBUF':'A'}[kind];bit=c['connections'][port][0]
   return bit,parity
  for c in ffs:assert through_not(c['connections']['CLK'][0])==(m['ports']['clk']['bits'][0],0),name
  expected_roots=[]
  for port in ['q0']+([] if unused else ['q1']):
   bit,inv=through_not(m['ports'][port]['bits'][0]);assert bit in drivers and drivers[bit][0]['type']=='MISTRAL_FF',(name,port,bit)
   ff=drivers[bit][0];assert inv==init,(name,'logical init polarity',inv,init)
   dbit,dinv=through_not(ff['connections']['DATAIN'][0]);assert dbit==m['ports']['d']['bits'][0] and dinv==inv,(name,'D polarity')
   expected_roots.append(bit)
  if not unused:assert (expected_roots[0]!=expected_roots[1])==bool(any(marks)),name
 result['passed']=True
try:
 for init in [0,1]:
  for label,marks in [('absent',(None,None)),('false',(0,0)),('one',(1,None)),('other',(None,1)),('both',(1,1))]:
   for mapped in [False,True]:run('%s_i%d_%s'%(label,init,'intel' if mapped else 'proc'),marks,init,mapped)
 for mapped in [False,True]:run('unused_'+('intel' if mapped else 'proc'),(1,1),0,mapped,True)
finally:
 (R/'receipt.json').write_text(json.dumps({'binary_sha256':hashlib.sha256(Path(binary).read_bytes()).hexdigest(),'results':results,'passed':len(results)==22 and all(x.get('passed') for x in results)},indent=2)+'\n')
print('PASS 22 focused cases')
