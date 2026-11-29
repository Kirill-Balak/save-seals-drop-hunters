"""Inline selected single-use procedures. Readable sources stay unchanged.

The Shrinko8 AST supplies lexical variable identity and source ranges. Arguments
are evaluated once. Fresh do-blocks retain local scopes. Early exits use a label
outside the procedure's inner block; three documented tail contexts may return
from their caller directly.
"""
from pathlib import Path
import sys,re
r=Path(__file__).resolve().parent.parent
sys.path.insert(0,str(r.parent/'rewards_v20/tools/vendor/shrinko8-main'))
from pico_tokenize import tokenize
from pico_parse import parse,NodeType,VarKind
from pico_srcdefs import Source

def source_name(name):
 while True:
  if name.startswith('inline_'):
   name=name[7:]
  clean=re.sub(r'_\d+_(?:p|\d+)$','',name)
  if clean==name:
   clean=re.sub(r'_\d+_\d+$','',name)
  if clean==name: break
  name=clean
 return name

MULTI={'level_menu'}
VALUES={'components','result_values','shortest_shift','contact_normal','star_position'}
ORDER='''level_menu components result_values shortest_shift contact_normal action_icon reset_fields fill_triangle spawn speed_limit recover_step move_actor blade_push physics break_ice make_ice update_fx update_scorefx draw_aim draw_hud control_icon draw_controls draw_scorefx award_area award_enemies seal_result lesson_validate lesson_next ghost_update dashed_line goal_arrow star_position draw_star_meter draw_results draw_actor start_cut draw_failure draw_loss load_progress retry_level continue_level'''.split()
TAIL={'physics','draw_hud','draw_failure','ghost_update'}

def inline_program(text):
 header,code=text.split('__lua__\n',1)
 serial=0
 for name in ORDER:
  while True:
   code,done=inline_one(code,name,serial)
   if not done:break
   serial+=1
 return header+'__lua__\n'+code

def inline_one(code,name,serial):
  src=Source('inline',code)
  tokens,errors=tokenize(src)
  assert not errors,errors
  tree,errors=parse(src,tokens)
  assert not errors,errors
  nodes=[]
  tree.traverse_nodes(lambda n:nodes.append(n))
  defs=[n for n in nodes if n.type==NodeType.function and n.name==name]
  calls=[n for n in nodes if n.type==NodeType.call and n.func.type==NodeType.var and n.func.name==name]
  if len(defs)!=1 or not calls or (name not in MULTI and len(calls)!=1):return code,False
  fn,call=defs[0],calls[0]
  refs=[n for n in nodes if n.type==NodeType.var and n.var is fn.target.var]
  if len(refs)!=len(calls)+1:return code,False
  assert len(call.args)<=len(fn.params),(name,len(fn.params),len(call.args))
  bstart,bend=fn.body.idx,fn.body.endidx
  edits=[];bindings=[]
  param_vars={p.var for p in fn.params}
  returns=[n for n in nodes if n.type==NodeType.return_ and bstart<=n.idx<n.endidx<=bend]
  output_vars={}
  output_stmt=None
  if name in VALUES:
   output_stmt=call.parent
   assert output_stmt.type==NodeType.local and output_stmt.sources==[call]
   assert len(returns)==1
   for target,item in zip(output_stmt.targets,returns[0].items):
    if item.type==NodeType.var and item.var.kind==VarKind.local:
     output_vars[item.var]=target.name
  local_names={}
  declared=set()
  for n in nodes:
   if bstart<=n.idx<n.endidx<=bend:
    if n.type in (NodeType.local,NodeType.for_in):
     declared.update(t.var for t in n.targets)
    elif n.type==NodeType.for_:
     declared.add(n.target.var)
  for n in nodes:
   if n.type==NodeType.var and n.var in declared and n.var not in param_vars and bstart<=n.idx<n.endidx<=bend:
    if n.var not in local_names:
     local_names[n.var]=output_vars.get(n.var,f'{source_name(n.var.name)}_{serial}_{len(local_names)}')
    edits.append((n.idx-bstart,n.endidx-bstart,local_names[n.var]))
  for i,param in enumerate(fn.params):
   arg=call.args[i] if i<len(call.args) else None
   value=arg.source_text if arg else 'nil'
   uses=[n for n in nodes if n.type==NodeType.var and n.var is param.var and bstart<=n.idx<n.endidx<=bend]
   if param.var.reassigned:
    replacement=f'{source_name(param.name)}_{serial}_p'
    bindings.append('local '+replacement+'='+value)
   elif not arg or arg.type==NodeType.const or re.fullmatch(r'[a-z_][a-z_0-9]*|-?\d+(?:\.\d+)?|true|false|nil',value):
    replacement=value
   elif len(uses)==1:
    replacement='('+value+')'
   else:
    replacement=f'{source_name(param.name)}_{serial}_p'
    bindings.append('local '+replacement+'='+value)
   for n in nodes:
    if n.type==NodeType.var and n.var is param.var and bstart<=n.idx<n.endidx<=bend:
     edits.append((n.idx-bstart,n.endidx-bstart,replacement))
  label=f'exit_{serial}'
  if name in VALUES:
   ret=returns[0]
   extra_targets=[];extra_values=[]
   for target,item in zip(output_stmt.targets,ret.items):
    if item.type==NodeType.var and item.var in output_vars:continue
    value=item.source_text
    for a,b,t in sorted(edits,reverse=True):
     aa,bb=a+bstart,b+bstart
     if item.idx<=aa<bb<=item.endidx:
      value=value[:aa-item.idx]+t+value[bb-item.idx:]
    extra_targets.append(target.name);extra_values.append(value)
   edits=[e for e in edits if not ret.idx-bstart<=e[0]<ret.endidx-bstart]
   replacement=('local '+','.join(extra_targets)+'='+','.join(extra_values)) if extra_targets else ''
   edits.append((ret.idx-bstart,ret.endidx-bstart,replacement))
  elif returns and name not in TAIL:
   for n in returns:
    assert n.source_text.strip()=='return',(name,n.source_text)
    edits.append((n.idx-bstart,n.endidx-bstart,'goto '+label))
  body=code[bstart:bend]
  for a,b,t in sorted(edits,reverse=True):body=body[:a]+t+body[b:]
  if returns and name not in TAIL and name not in VALUES:
   body='do\n'+body+'\nend\n::'+label+'::'
  # Unique locals cannot shadow caller variables, so a wrapping scope is
  # needed only for early-exit labels.
  replacement='\n'+'\n'.join(bindings)+'\n'+body+'\n'
  site=output_stmt or call
  changes=[(site.idx,site.endidx,replacement)]
  if len(calls)==1:changes.append((fn.idx,fn.endidx,''))
  for a,b,t in sorted(changes,reverse=True):
   code=code[:a]+t+code[b:]
  return code,True
