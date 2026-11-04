import base64,importlib.util,json,os,pathlib,plistlib,subprocess,sys,tempfile,unittest,xml.etree.ElementTree as ET
ROOT=pathlib.Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'scripts'))
spec=importlib.util.spec_from_file_location('appcast',ROOT/'scripts/validate-appcast.py');appcast=importlib.util.module_from_spec(spec);spec.loader.exec_module(appcast)
S=appcast.S
class ReleaseTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.root=pathlib.Path(self.temp.name)
    def tearDown(self): self.temp.cleanup()
    def feed(self,name,entries):
        rss=ET.Element('rss');ch=ET.SubElement(rss,'channel')
        for version,build,channel,signature in entries:
            item=ET.SubElement(ch,'item');ET.SubElement(item,S+'version').text=str(build);ET.SubElement(item,S+'shortVersionString').text=version
            if channel: ET.SubElement(item,S+'channel').text=channel
            ET.SubElement(item,'enclosure',{'url':f'https://github.com/akaanuzman/DevIsland-releases/releases/download/v{version}/Dev-Island-{version}-arm64.dmg','length':'42',S+'edSignature':signature})
        path=self.root/name;ET.ElementTree(rss).write(path);return path
    def test_feed_preserves_history_and_rejects_unsigned_and_rollback(self):
        old=self.feed('old.xml',[('0.3.7',10,None,'old')])
        new=self.feed('new.xml',[('0.3.7',10,None,'old'),('0.4.0',11,None,'valid')])
        self.assertEqual(appcast.validate(new,old,'0.4.0',11),2)
        for entries in [[('0.4.0',11,None,'valid')],[('0.3.7',10,None,'old'),('0.4.0',11,None,'')],[('0.3.7',10,None,'old'),('0.4.0',11,'beta','valid')]]:
            with self.assertRaises(ValueError):appcast.validate(self.feed('bad.xml',entries),old,'0.4.0',11)
        with self.assertRaises(ValueError):appcast.validate(new,new,'0.4.0',11)
    def test_beta_channel_is_explicit(self):
        empty=self.root/'missing'
        valid=self.feed('beta.xml',[('0.4.0-beta.1',11,'beta','valid')])
        self.assertEqual(appcast.validate(valid,empty,'0.4.0-beta.1',11),1)
        invalid=self.feed('invalid.xml',[('0.4.0-beta.1',11,None,'valid')])
        with self.assertRaises(ValueError): appcast.validate(invalid,empty,'0.4.0-beta.1',11)
    def test_official_build_requires_developer_id_and_matching_key_shape(self):
        p=self.root/'Info.plist';p.write_bytes(plistlib.dumps({'CFBundleIdentifier':'dev.island.app'}))
        command=[sys.executable,str(ROOT/'scripts/configure-updates.py'),str(p)]
        env=dict(os.environ,DEV_ISLAND_OFFICIAL_RELEASE='1',DEV_ISLAND_SIGN_IDENTITY='-',SPARKLE_PUBLIC_KEY=base64.b64encode(os.urandom(32)).decode())
        self.assertNotEqual(subprocess.run(command,env=env,capture_output=True).returncode,0)
        env['DEV_ISLAND_SIGN_IDENTITY']='Developer ID Application: Fixture (TEST)'
        subprocess.run(command,env=env,check=True)
        data=plistlib.loads(p.read_bytes());self.assertTrue(data['DevIslandOfficialRelease']);self.assertFalse(data['SUAutomaticallyUpdate']);self.assertEqual(data['SUScheduledCheckInterval'],3600)
        env['SPARKLE_PUBLIC_KEY']='short'
        self.assertNotEqual(subprocess.run(command,env=env,capture_output=True).returncode,0)
    def test_single_source_bundle_and_helper_version(self):
        meta=json.loads((ROOT/'Resources/version.json').read_text());plist=plistlib.loads((ROOT/'Resources/Info.plist').read_bytes())
        self.assertEqual(plist['CFBundleShortVersionString'],meta['version']);self.assertEqual(plist['CFBundleVersion'],str(meta['build']))
        self.assertIn(json.dumps(meta['version']),(ROOT/'Sources/DevIslandCore/BuildInfo.swift').read_text())
    def test_real_sparkle_signatures_reject_wrong_key_tamper_and_truncation(self):
        tool=ROOT/'.build/artifacts/sparkle/Sparkle/bin/sign_update'
        self.assertTrue(tool.exists(),'Resolve Sparkle before running release tests')
        key=self.root/'test.key';key.write_text(base64.b64encode(os.urandom(32)).decode());key.chmod(0o600)
        wrong=self.root/'wrong.key';wrong.write_text(base64.b64encode(os.urandom(32)).decode());wrong.chmod(0o600)
        archive=self.root/'fixture.zip';archive.write_bytes(b'Archive fixture for real Sparkle EdDSA verification'*100)
        signature=subprocess.check_output([str(tool),'--ed-key-file',str(key),'-p',str(archive)],text=True).strip()
        def verify(path,signing_key=key):return subprocess.run([str(tool),'--ed-key-file',str(signing_key),'--verify',str(path),signature],capture_output=True).returncode
        self.assertEqual(verify(archive),0);self.assertNotEqual(verify(archive,wrong),0)
        data=archive.read_bytes();archive.write_bytes(data+b'tamper');self.assertNotEqual(verify(archive),0)
        archive.write_bytes(data[:20]);self.assertNotEqual(verify(archive),0)
