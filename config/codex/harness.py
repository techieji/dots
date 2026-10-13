#!/usr/bin/env python3
import argparse,contextlib,datetime as dt,hashlib,json,os,re,shutil,sqlite3,subprocess,sys,tempfile,uuid
from pathlib import Path
APP="codex-harness"; STATE=Path(os.getenv("XDG_STATE_HOME",Path.home()/".local/state"))/APP
DATA=Path(os.getenv("XDG_DATA_HOME",Path.home()/".local/share"))/APP
CONFIG=Path(os.getenv("XDG_CONFIG_HOME",Path.home()/".config"))/APP
SKILLS=Path.home()/".agents/skills"; DB=STATE/"harness.sqlite3"
DEFAULT={"prompt_retention_days":30,"failed_worktree_retention_days":7,"archive_unused_days":90,"prompt_max_bytes":8192,"memory_injection_max_chars":4000,"memory_match_limit":2,"skill_limit":40,"same_task_threshold":.68,"classification_threshold":.45,"memory_word_limit":800,"skill_word_limit":1200,"retry_minutes":[5,15,45]}
SECRETS=[
(re.compile(r"-----BEGIN [^-]+-----.*?-----END [^-]+-----",re.S),"[REDACTED PEM]"),
(re.compile(r"\beyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\b"),"[REDACTED JWT]"),
(re.compile(r"(?i)\b(api[_-]?key|token|secret|password|passwd|authorization)\s*[:=]\s*[^\s,;]+"),r"\1=[REDACTED]"),
(re.compile(r"https?://[^\s/?#]+[^\s]*[?&](?:token|key|secret|signature|sig|auth)=[^\s&#]+",re.I),"[REDACTED URL]"),
(re.compile(r"\b(?:sk|ghp|github_pat|xox[baprs])[-_][A-Za-z0-9_-]{16,}\b"),"[REDACTED TOKEN]"),
(re.compile(r"\b[A-Za-z0-9+/=_-]{40,}\b"),"[REDACTED HIGH-ENTROPY TOKEN]")]
FORBIDDEN=[re.compile(x,re.I) for x in [r"(^|[;&|]\s*)nh\s+os\s+switch(?:\s+\.|\s|$)",r"nix-env\s+.*--delete-generations",r"nix-collect-garbage\s+.*(?:-d|--delete-old)",r"bootloader.*(?:delete|remove|prune).*(?:generation|entry)",r"(?:delete|remove|prune).*(?:bootloader|system-boot|grub).*(?:generation|entry)"]]
BAD_ART=[re.compile(x,re.I) for x in [r"/(?:home|Users)/[^/\s]+/",r"\bsudo\b",r"\b(?:rm\s+-rf|mkfs\b|dd\s+if=|git\s+reset\s+--hard)",r"\x60\x60\x60(?:bash|sh|python|javascript|nix)?"]]
def now(): return dt.datetime.now(dt.timezone.utc).isoformat()
def policy():
 try:return DEFAULT|json.loads((CONFIG/"policy.json").read_text())
 except (OSError,json.JSONDecodeError):return DEFAULT.copy()
def dirs():
 for p in (STATE,DATA,DATA/"artifacts",DATA/"memories",DATA/"jobs",DATA/"worktrees",DATA/"archive",SKILLS):p.mkdir(parents=True,exist_ok=True)
def connect():
 dirs(); d=sqlite3.connect(DB,timeout=5);d.row_factory=sqlite3.Row
 d.executescript("""PRAGMA journal_mode=WAL; PRAGMA foreign_keys=ON;
 CREATE TABLE IF NOT EXISTS clusters(id INTEGER PRIMARY KEY,slug TEXT UNIQUE,centroid TEXT NOT NULL,created_at TEXT NOT NULL,updated_at TEXT NOT NULL);
 CREATE TABLE IF NOT EXISTS turns(turn_id TEXT PRIMARY KEY,session_id TEXT,cwd TEXT,prompt TEXT,normalized TEXT,response TEXT,success INTEGER NOT NULL DEFAULT 0,internal INTEGER NOT NULL DEFAULT 0,cluster_id INTEGER REFERENCES clusters(id),created_at TEXT NOT NULL,completed_at TEXT);
 CREATE TABLE IF NOT EXISTS artifact_versions(id INTEGER PRIMARY KEY,cluster_id INTEGER NOT NULL REFERENCES clusters(id),version INTEGER NOT NULL,slug TEXT NOT NULL,path TEXT NOT NULL,memory_path TEXT NOT NULL,active INTEGER NOT NULL DEFAULT 0,disabled INTEGER NOT NULL DEFAULT 0,approved INTEGER NOT NULL DEFAULT 0,created_at TEXT NOT NULL,last_used_at TEXT,UNIQUE(cluster_id,version));
 CREATE TABLE IF NOT EXISTS jobs(id TEXT PRIMARY KEY,kind TEXT NOT NULL,repo TEXT,prompt_path TEXT,turn_id TEXT,status TEXT NOT NULL,attempt INTEGER NOT NULL DEFAULT 0,next_attempt_at TEXT,worktree TEXT,result_path TEXT,error TEXT,created_at TEXT NOT NULL,updated_at TEXT NOT NULL);
 CREATE TABLE IF NOT EXISTS token_metrics(id INTEGER PRIMARY KEY,job_id TEXT NOT NULL,input_tokens INTEGER DEFAULT 0,cached_input_tokens INTEGER DEFAULT 0,output_tokens INTEGER DEFAULT 0,recorded_at TEXT NOT NULL);""");return d
def redact(s,limit=None):
 for p,r in SECRETS:s=p.sub(r,s)
 return s.encode()[:limit].decode(errors="ignore") if limit else s
def words(s):return re.findall(r"[a-z0-9]+",s.lower())
def norm(s):return " ".join(x for x in words(s) if len(x)>1)
def grams(s):
 w=words(s);return set(w),{a+" "+b for a,b in zip(w,w[1:])}
def sim(a,b):
 au,ab=grams(a);bu,bb=grams(b);den=len(au|bu)+2*len(ab|bb);return (len(au&bu)+2*len(ab&bb))/den if den else 1
def event():
 try:return json.load(sys.stdin)
 except:return {}
def eid(e):return str(e.get("turn_id") or e.get("turnId") or uuid.uuid4())
def wake():dirs();(STATE/"wake").touch()
def guard(e):
 v=e.get("tool_input",e.get("toolInput",e.get("input",{})))
 c=" ".join(str(v.get(k,"")) for k in ("cmd","command","args")).strip() if isinstance(v,dict) else str(v)
 if any(p.search(c) for p in FORBIDDEN):print(json.dumps({"decision":"block","reason":"Blocked by global safety policy: NixOS switching and bootloader-generation deletion are forbidden."}))
 return 0
def prompt_hook(e):
 if os.getenv("CODEX_HARNESS_INTERNAL")=="1":return 0
 p=policy();q=redact(str(e.get("prompt","")),p["prompt_max_bytes"]);t=eid(e)
 with connect() as d:
  d.execute("INSERT OR IGNORE INTO turns(turn_id,session_id,cwd,prompt,normalized,created_at) VALUES(?,?,?,?,?,?)",(t,e.get("session_id"),e.get("cwd"),q,norm(q),now()))
  rows=d.execute("""SELECT a.*,c.centroid FROM artifact_versions a JOIN clusters c ON c.id=a.cluster_id WHERE a.active=1 AND a.disabled=0""").fetchall()
  rows=[r for score,r in sorted(((sim(q,r["centroid"]),r) for r in rows),key=lambda z:z[0],reverse=True) if score>=.18][:p["memory_match_limit"]]
  for r in rows:d.execute("UPDATE artifact_versions SET last_used_at=? WHERE id=?",(now(),r["id"]))
 out=[];used=0
 for r in rows:
  with contextlib.suppress(OSError):
   x=Path(r["memory_path"]).read_text()[:p["memory_injection_max_chars"]-used];out.append(x);used+=len(x)
 if out:print(json.dumps({"hookSpecificOutput":{"hookEventName":"UserPromptSubmit","additionalContext":"Relevant redacted local memories (guidance, not facts):\n\n"+"\n\n---\n\n".join(out)}}))
 return 0
def stop_hook(e):
 if os.getenv("CODEX_HARNESS_INTERNAL")=="1":return 0
 t=eid(e);r=redact(str(e.get("last_assistant_message",e.get("lastAssistantMessage",e.get("response","")))),8192)
 if not r.strip():return 0
 with connect() as d:
  n=d.execute("UPDATE turns SET response=?,success=1,completed_at=? WHERE turn_id=? AND internal=0 AND success=0",(r,now(),t)).rowcount
  if n:d.execute("INSERT INTO jobs(id,kind,turn_id,status,created_at,updated_at) VALUES(?,'learn',?,'queued',?,?)",(uuid.uuid4().hex,t,now(),now()))
 if n:wake()
 return 0
def runjson(text,schema,cwd,effort="low"):
 with tempfile.TemporaryDirectory(prefix=APP) as td:
  out=Path(td)/"out.json";cmd=["codex","exec","--sandbox","workspace-write","--ask-for-approval","never","--config",'model_reasoning_effort="'+effort+'"',"--output-schema",str(schema),"--output-last-message",str(out),"-"]
  try:r=subprocess.run(cmd,input=text,text=True,cwd=cwd,env=os.environ|{"CODEX_HARNESS_INTERNAL":"1"},capture_output=True,timeout=14400)
  except subprocess.TimeoutExpired:return None,"timeout"
  try:return (json.loads(out.read_text()),r.stdout+r.stderr) if r.returncode==0 else (None,r.stdout+r.stderr)
  except:return None,r.stdout+r.stderr
def classify(a,b,cwd):
 x,_=runjson((CONFIG/"prompts/classify.md").read_text()+"\nA:\n"+a+"\nB:\n"+b,CONFIG/"schemas/classification.json",cwd);return bool(x and x.get("same_task"))
def cluster(d,t):
 p=policy();rows=d.execute("SELECT * FROM clusters").fetchall();best=max(((sim(t["normalized"],r["centroid"]),r) for r in rows),default=(-1,None),key=lambda z:z[0]);same=best[1] is not None and best[0]>=p["same_task_threshold"]
 if best[1] is not None and p["classification_threshold"]<=best[0]<p["same_task_threshold"]:same=classify(t["prompt"],best[1]["centroid"],Path(t["cwd"]) if t["cwd"] and Path(t["cwd"]).is_dir() else Path.home())
 if same:cid=best[1]["id"];d.execute("UPDATE clusters SET updated_at=? WHERE id=?",(now(),cid))
 else:
  slug="task-"+hashlib.sha256(t["normalized"].encode()).hexdigest()[:12];cid=d.execute("INSERT INTO clusters(slug,centroid,created_at,updated_at) VALUES(?,?,?,?)",(slug,t["normalized"],now(),now())).lastrowid
 d.execute("UPDATE turns SET cluster_id=? WHERE turn_id=?",(cid,t["turn_id"]));return cid
def validate(o):
 if not {"slug","name","description","memory","skill"}<=o.keys():return False,"missing fields"
 if not re.fullmatch(r"[a-z0-9]+(?:-[a-z0-9]+)*",str(o["slug"])):return False,"bad slug"
 p=policy()
 if len(o["memory"].split())>p["memory_word_limit"] or len(o["skill"].split())>p["skill_word_limit"]:return False,"word limit"
 text="\n".join(map(str,o.values()))
 if redact(text)!=text or any(x.search(text) for x in BAD_ART):return False,"static safety rejection"
 if "name:" not in o["skill"] or "description:" not in o["skill"]:return False,"missing skill frontmatter"
 return True,"ok"
def activate(d,cid,o):
 old=d.execute("SELECT * FROM artifact_versions WHERE cluster_id=? ORDER BY version DESC",(cid,)).fetchone();count=d.execute("SELECT COUNT(*) FROM artifact_versions WHERE active=1 AND disabled=0").fetchone()[0]
 if not old and count>=policy()["skill_limit"]:raise RuntimeError("active skill limit reached")
 v=old["version"]+1 if old else 1;root=DATA/"artifacts"/o["slug"]/("v"+str(v));root.mkdir(parents=True)
 (root/"SKILL.md").write_text(o["skill"].rstrip()+"\n");mem=DATA/"memories"/("{}-v{}.md".format(o["slug"],v));mem.write_text(o["memory"].rstrip()+"\n")
 d.execute("UPDATE artifact_versions SET active=0 WHERE cluster_id=?",(cid,));d.execute("INSERT INTO artifact_versions(cluster_id,version,slug,path,memory_path,active,approved,created_at,last_used_at) VALUES(?,?,?,?,?,1,1,?,?)",(cid,v,o["slug"],str(root),str(mem),now(),now()))
 link=SKILLS/("generated-"+o["slug"]);tmp=SKILLS/(".tmp-"+uuid.uuid4().hex);tmp.symlink_to(root,True);os.replace(tmp,link)
def learn(j):
 with connect() as d:
  t=d.execute("SELECT * FROM turns WHERE turn_id=? AND success=1 AND internal=0",(j["turn_id"],)).fetchone()
  if not t:return
  cid=t["cluster_id"] or cluster(d,t);n=d.execute("SELECT COUNT(DISTINCT turn_id) FROM turns WHERE cluster_id=? AND success=1",(cid,)).fetchone()[0];exists=d.execute("SELECT 1 FROM artifact_versions WHERE cluster_id=?",(cid,)).fetchone();d.commit()
  if n<2 or exists:return
  rows=d.execute("SELECT prompt,response FROM turns WHERE cluster_id=? AND success=1 ORDER BY completed_at LIMIT 6",(cid,)).fetchall();examples="\n\n".join("PROMPT:\n"+r["prompt"]+"\nRESPONSE:\n"+r["response"] for r in rows);cwd=Path(t["cwd"]) if t["cwd"] and Path(t["cwd"]).is_dir() else Path.home()
  o,log=runjson((CONFIG/"prompts/generate.md").read_text()+"\n"+examples,CONFIG/"schemas/artifact.json",cwd)
  if not o:raise RuntimeError("generation failed: "+log[-800:])
  ok,msg=validate(o)
  if not ok:raise RuntimeError(msg)
  review,log=runjson((CONFIG/"prompts/review.md").read_text()+"\nPROPOSAL:\n"+json.dumps(o),CONFIG/"schemas/review.json",cwd)
  if not review or not review.get("approved"):raise RuntimeError("review rejected: "+str((review or {}).get("reason",log[-800:])))
  activate(d,cid,o);d.commit()
def notify(a,b):
 with contextlib.suppress(Exception):subprocess.run(["notify-send",a,b],timeout=5)
def usage(d,j,line):
 with contextlib.suppress(Exception):
  e=json.loads(line);u=e.get("usage") or e.get("token_usage") or {};d.execute("INSERT INTO token_metrics(job_id,input_tokens,cached_input_tokens,output_tokens,recorded_at) VALUES(?,?,?,?,?)",(j,u.get("input_tokens",0),u.get("cached_input_tokens",0),u.get("output_tokens",0),now()))
def execute(j):
 repo=Path(j["repo"]).resolve();jid=j["id"];wt=DATA/"worktrees"/jid;out=DATA/"jobs"/jid;out.mkdir(parents=True,exist_ok=True)
 if subprocess.run(["git","-C",str(repo),"rev-parse","--git-dir"],capture_output=True).returncode:raise RuntimeError("not a Git worktree")
 if not wt.exists():subprocess.run(["git","-C",str(repo),"worktree","add","--detach",str(wt),"HEAD"],check=True,capture_output=True)
 with connect() as d:d.execute("UPDATE jobs SET worktree=?,updated_at=? WHERE id=?",(str(wt),now(),jid));d.commit()
 cmd=["codex","exec","--json","--sandbox","workspace-write","--ask-for-approval","never","--output-last-message",str(out/"final.md"),"-"];env=os.environ|{"CODEX_HARNESS_INTERNAL":"1"}
 with (out/"events.jsonl").open("w") as log:
  p=subprocess.Popen(cmd,stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,cwd=wt,env=env);p.stdin.write(Path(j["prompt_path"]).read_text());p.stdin.close()
  with connect() as d:
   for line in p.stdout:log.write(line);usage(d,jid,line)
   d.commit()
  rc=p.wait(timeout=14400)
 (out/"changes.patch").write_text(subprocess.run(["git","-C",str(wt),"diff","--binary"],capture_output=True,text=True).stdout)
 if rc:raise RuntimeError("codex exited "+str(rc))
 subprocess.run(["git","-C",str(repo),"worktree","remove","--force",str(wt)],capture_output=True)
 with connect() as d:d.execute("UPDATE jobs SET result_path=? WHERE id=?",(str(out),jid));d.commit()
 notify("Codex harness","Job "+jid+" completed; patch retained.")
def claim():
 with connect() as d:
  d.execute("BEGIN IMMEDIATE");j=d.execute("SELECT * FROM jobs WHERE status IN ('queued','retry') AND (next_attempt_at IS NULL OR next_attempt_at<=?) ORDER BY created_at LIMIT 1",(now(),)).fetchone()
  if j:d.execute("UPDATE jobs SET status='running',attempt=attempt+1,updated_at=? WHERE id=?",(now(),j["id"]))
  d.commit();return j
def failed(j,e):
 text=str(e);trans=any(x in text.lower() for x in ("rate limit","transport","timeout","connection"));attempt=j["attempt"]+1;delays=policy()["retry_minutes"]
 if trans and attempt<=len(delays):status="retry";nxt=(dt.datetime.now(dt.timezone.utc)+dt.timedelta(minutes=delays[attempt-1])).isoformat()
 else:status="failed";nxt=None
 with connect() as d:d.execute("UPDATE jobs SET status=?,next_attempt_at=?,error=?,updated_at=? WHERE id=?",(status,nxt,redact(text,4096),now(),j["id"]));d.commit()
 notify("Codex harness","Job "+j["id"]+" "+status)
def worker():
 while True:
  j=claim()
  if not j:return 0
  try:
   learn(j) if j["kind"]=="learn" else execute(j)
   with connect() as d:d.execute("UPDATE jobs SET status='complete',updated_at=? WHERE id=?",(now(),j["id"]));d.commit()
  except Exception as e:failed(j,e)
def enqueue(repo,pf):
 src=Path(pf)
 if not src.is_file():raise SystemExit("prompt file not found")
 jid=uuid.uuid4().hex;dest=DATA/"jobs"/jid/"prompt.md";dest.parent.mkdir(parents=True,exist_ok=True);dest.write_text(redact(src.read_text()))
 with connect() as d:d.execute("INSERT INTO jobs(id,kind,repo,prompt_path,status,created_at,updated_at) VALUES(?,'exec',?,?,'queued',?,?)",(jid,str(Path(repo).resolve()),str(dest),now(),now()));d.commit()
 wake();return jid
def links(d):
 expected={"generated-"+r["slug"]:Path(r["path"]) for r in d.execute("SELECT * FROM artifact_versions WHERE active=1 AND disabled=0")}
 for x in SKILLS.glob("generated-*"):
  if x.name not in expected and x.is_symlink():x.unlink()
 for name,target in expected.items():
  link=SKILLS/name
  if not link.exists() or link.resolve()!=target.resolve():
   tmp=SKILLS/(".tmp-"+uuid.uuid4().hex);tmp.symlink_to(target,True);os.replace(tmp,link)
def maintain():
 p=policy();stamp=dt.datetime.now(dt.timezone.utc);cut=(stamp-dt.timedelta(days=p["prompt_retention_days"])).isoformat();archive=(stamp-dt.timedelta(days=p["archive_unused_days"])).isoformat()
 with connect() as d:d.execute("UPDATE turns SET prompt='',response='' WHERE created_at<?",(cut,));d.execute("UPDATE artifact_versions SET active=0 WHERE active=1 AND COALESCE(last_used_at,created_at)<?",(archive,));links(d);d.commit()
 fcut=stamp-dt.timedelta(days=p["failed_worktree_retention_days"])
 for x in (DATA/"worktrees").glob("*"):
  with contextlib.suppress(OSError):
   if dt.datetime.fromtimestamp(x.stat().st_mtime,dt.timezone.utc)<fcut:shutil.rmtree(x)
 return 0
def artifacts(kind,action,value):
 with connect() as d:
  if action=="list":
   print(json.dumps([dict(r) for r in d.execute("SELECT id,slug,version,active,disabled,created_at FROM artifact_versions ORDER BY id")],indent=2));return 0
  if kind=="memories":
   rows=d.execute("SELECT * FROM artifact_versions WHERE slug=?",(value,)).fetchall()
   for r in rows:Path(r["memory_path"]).unlink(missing_ok=True)
   d.execute("DELETE FROM artifact_versions WHERE slug=?",(value,));d.commit();links(d);return 0
  r=d.execute("SELECT * FROM artifact_versions WHERE slug=? ORDER BY version DESC LIMIT 1",(value,)).fetchone()
  if not r:raise SystemExit("unknown artifact")
  if action=="disable":d.execute("UPDATE artifact_versions SET disabled=1,active=0 WHERE slug=?",(value,))
  elif action=="enable":d.execute("UPDATE artifact_versions SET active=0 WHERE cluster_id=?",(r["cluster_id"],));d.execute("UPDATE artifact_versions SET disabled=0,active=1 WHERE id=?",(r["id"],))
  else:
   prior=d.execute("SELECT * FROM artifact_versions WHERE cluster_id=? AND version<? ORDER BY version DESC LIMIT 1",(r["cluster_id"],r["version"])).fetchone()
   if not prior:raise SystemExit("no prior version")
   d.execute("UPDATE artifact_versions SET active=0 WHERE cluster_id=?",(r["cluster_id"],));d.execute("UPDATE artifact_versions SET disabled=0,active=1 WHERE id=?",(prior["id"],))
  d.commit();links(d);return 0
def main():
 a=argparse.ArgumentParser();sub=a.add_subparsers(dest="cmd",required=True)
 h=sub.add_parser("hook");h.add_argument("event",choices=["prompt","stop","guard"])
 e=sub.add_parser("enqueue");e.add_argument("--repo",required=True);e.add_argument("--prompt",required=True)
 st=sub.add_parser("status");st.add_argument("job",nargs="?")
 lg=sub.add_parser("logs");lg.add_argument("job");rs=sub.add_parser("resume");rs.add_argument("job")
 sub.add_parser("worker");sub.add_parser("maintain")
 for k,acts in [("skills",["list","disable","enable","rollback"]),("memories",["list","forget"])]:
  x=sub.add_parser(k);x.add_argument("action",choices=acts);x.add_argument("value",nargs="?")
 x=a.parse_args()
 if x.cmd=="hook":return {"prompt":prompt_hook,"stop":stop_hook,"guard":guard}[x.event](event())
 if x.cmd=="enqueue":print(enqueue(x.repo,x.prompt));return 0
 if x.cmd=="worker":return worker()
 if x.cmd=="maintain":return maintain()
 if x.cmd=="status":
  with connect() as d:
   if x.job:r=d.execute("SELECT * FROM jobs WHERE id=?",(x.job,)).fetchone();print(json.dumps(dict(r) if r else {},indent=2))
   else:print(json.dumps([dict(r) for r in d.execute("SELECT id,kind,status,attempt,created_at,updated_at FROM jobs ORDER BY created_at DESC LIMIT 30")],indent=2))
  return 0
 if x.cmd=="logs":
  for n in ["events.jsonl","final.md","changes.patch"]:
   p=DATA/"jobs"/x.job/n
   if p.exists():print("== "+n+" ==\n"+p.read_text())
  return 0
 if x.cmd=="resume":
  with connect() as d:
   n=d.execute("UPDATE jobs SET status='queued',next_attempt_at=NULL,updated_at=? WHERE id=? AND status IN ('failed','retry')",(now(),x.job)).rowcount;d.commit()
  if not n:raise SystemExit("job is not resumable")
  wake();return 0
 if x.cmd in ("skills","memories"):
  if x.action!="list" and not x.value:raise SystemExit("artifact slug required")
  return artifacts(x.cmd,x.action,x.value)
if __name__=="__main__":raise SystemExit(main())
