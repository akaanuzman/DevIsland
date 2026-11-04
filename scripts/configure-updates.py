#!/usr/bin/env python3
import base64,os,pathlib,plistlib,sys
p=pathlib.Path(sys.argv[1]); info=plistlib.loads(p.read_bytes())
official=os.environ.get('DEV_ISLAND_OFFICIAL_RELEASE')=='1'
if official:
    if not os.environ.get('DEV_ISLAND_SIGN_IDENTITY','').startswith('Developer ID Application:'):
        raise SystemExit('Official releases require a Developer ID Application identity')
    key=os.environ.get('SPARKLE_PUBLIC_KEY','')
    if len(base64.b64decode(key,validate=True))!=32: raise SystemExit('Missing/invalid Sparkle public key')
    info.update(SUPublicEDKey=key, SUFeedURL='https://akaanuzman.github.io/DevIsland-releases/appcast.xml',
                SUEnableAutomaticChecks=True, SUScheduledCheckInterval=3600, SUAutomaticallyUpdate=False,
                SUAllowsAutomaticUpdates=False, SUEnableSystemProfiling=False, SUVerifyUpdateBeforeExtraction=True)
info['DevIslandOfficialRelease']=official
p.write_bytes(plistlib.dumps(info))
