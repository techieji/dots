import importlib.util,json,os,tempfile,unittest
from pathlib import Path
SPEC=importlib.util.spec_from_file_location("harness",Path(__file__).parents[1]/"harness.py")
H=importlib.util.module_from_spec(SPEC);SPEC.loader.exec_module(H)
class HarnessTests(unittest.TestCase):
 def setUp(self):
  self.t=tempfile.TemporaryDirectory();root=Path(self.t.name)
  H.STATE=root/"state";H.DATA=root/"data";H.CONFIG=root/"config";H.SKILLS=root/"skills";H.DB=H.STATE/"db.sqlite"
  H.CONFIG.mkdir();(H.CONFIG/"policy.json").write_text(json.dumps(H.DEFAULT))
 def tearDown(self):self.t.cleanup()
 def test_redaction(self):
  value="password=hunter2 token=abc https://x.test/a?token=secret eyJabc.def.ghi"
  out=H.redact(value);self.assertNotIn("hunter2",out);self.assertNotIn("secret",out);self.assertNotIn("eyJabc",out)
 def test_similarity_thresholds(self):
  self.assertGreaterEqual(H.sim("fix failing nix build","fix failing nix build"),.68)
  self.assertLess(H.sim("fix nix build","draw watercolor fox"),.45)
 def test_guard_patterns(self):
  self.assertTrue(any(p.search("nh os switch .") for p in H.FORBIDDEN))
  self.assertTrue(any(p.search("nix-env --delete-generations old") for p in H.FORBIDDEN))
 def test_validation(self):
  good={"slug":"nix-fix","name":"Nix fix","description":"Fix Nix issues","memory":"Validate before activation.","skill":"---\nname: nix-fix\ndescription: Fix Nix issues\n---\nValidate the change."}
  self.assertTrue(H.validate(good)[0]);bad=good|{"memory":"Use sudo and /home/alice/private"};self.assertFalse(H.validate(bad)[0])
 def test_atomic_activation_and_rollback_data(self):
  with H.connect() as d:
   cid=d.execute("INSERT INTO clusters(slug,centroid,created_at,updated_at) VALUES('x','x',?,?)",(H.now(),H.now())).lastrowid
   obj={"slug":"nix-fix","name":"Nix fix","description":"Fix Nix","memory":"Remember validation.","skill":"---\nname: nix-fix\ndescription: Fix Nix\n---\nValidate."}
   H.activate(d,cid,obj);d.commit();self.assertTrue((H.SKILLS/"generated-nix-fix").is_symlink())
   H.activate(d,cid,obj);d.commit();self.assertEqual(d.execute("SELECT COUNT(*) FROM artifact_versions").fetchone()[0],2)
 def test_first_success_no_skill_second_activates_one(self):
  with H.connect() as d:
   for i in range(2):
    d.execute("INSERT INTO turns(turn_id,cwd,prompt,normalized,response,success,created_at,completed_at) VALUES(?,?,?,?,?,1,?,?)",(str(i),self.t.name,"fix nix build","fix nix build","done",H.now(),H.now()))
   first=d.execute("SELECT * FROM turns WHERE turn_id='0'").fetchone();cid=H.cluster(d,first)
   self.assertEqual(d.execute("SELECT COUNT(DISTINCT turn_id) FROM turns WHERE cluster_id=?",(cid,)).fetchone()[0],1)
   second=d.execute("SELECT * FROM turns WHERE turn_id='1'").fetchone();self.assertEqual(H.cluster(d,second),cid)
   self.assertEqual(d.execute("SELECT COUNT(DISTINCT turn_id) FROM turns WHERE cluster_id=?",(cid,)).fetchone()[0],2)
if __name__=="__main__":unittest.main()
